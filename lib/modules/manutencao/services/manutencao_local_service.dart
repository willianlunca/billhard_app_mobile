import 'dart:convert';
import 'dart:io';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:billhard_app_mobile/shared/services/pagina_persistente_service.dart';

import 'deck_service.dart';

class OperacaoManutencao {
  final String id;
  final int boardId;
  final int cardId;
  final String tipo;
  final String texto;
  final String arquivo;
  final String nomeArquivo;
  final DateTime criadaEm;
  final bool enviada;

  const OperacaoManutencao({
    required this.id,
    required this.boardId,
    required this.cardId,
    required this.tipo,
    required this.texto,
    required this.arquivo,
    required this.nomeArquivo,
    required this.criadaEm,
    this.enviada = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'boardId': boardId,
    'cardId': cardId,
    'tipo': tipo,
    'texto': texto,
    'arquivo': arquivo,
    'nomeArquivo': nomeArquivo,
    'criadaEm': criadaEm.toIso8601String(),
    'enviada': enviada,
  };

  factory OperacaoManutencao.fromJson(Map json) {
    return OperacaoManutencao(
      id: '${json['id']}',
      boardId: (json['boardId'] as num).toInt(),
      cardId: (json['cardId'] as num).toInt(),
      tipo: '${json['tipo']}',
      texto: '${json['texto'] ?? ''}',
      arquivo: '${json['arquivo'] ?? ''}',
      nomeArquivo: '${json['nomeArquivo'] ?? ''}',
      criadaEm: DateTime.parse('${json['criadaEm']}'),
      enviada: json['enviada'] == true,
    );
  }

  OperacaoManutencao enviado() {
    return OperacaoManutencao(
      id: id,
      boardId: boardId,
      cardId: cardId,
      tipo: tipo,
      texto: texto,
      arquivo: arquivo,
      nomeArquivo: nomeArquivo,
      criadaEm: criadaEm,
      enviada: true,
    );
  }
}

class ManutencaoLocalService {
  static Future<void>? _init;
  static final Map<String, Future<Box<String>>> _aberturas = {};

  String get _uid {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw StateError('Usuário não autenticado.');
    }

    return user.id;
  }

  Future<Box<String>> get box async {
    _init ??= Hive.initFlutter();
    await _init;

    final nome = 'billhard_manutencao_${_uid.replaceAll('-', '_')}';

    final anterior = _aberturas[nome];

    if (anterior != null) {
      final aberta = await anterior;
      if (aberta.isOpen) return aberta;
      _aberturas.remove(nome);
    }

    final abertura = Hive.openBox<String>(nome);
    _aberturas[nome] = abertura;

    try {
      return await abertura;
    } catch (_) {
      _aberturas.remove(nome);
      rethrow;
    }
  }

  String _chave(int boardId, int cardId) => '$boardId:$cardId';

  Future<bool> historicoConclusao(int boardId, int cardId) async {
    final b = await box;
    return b.containsKey('historico:${_chave(boardId, cardId)}') ||
        b.containsKey('visita:${_chave(boardId, cardId)}');
  }

  Future<void> registrarHistorico(int boardId, int cardId) async {
    final b = await box;

    await b.put(
      'historico:${_chave(boardId, cardId)}',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> reabrirVisita(int boardId, int cardId) async {
    final b = await box;

    await registrarHistorico(boardId, cardId);

    await b.delete('visita:${_chave(boardId, cardId)}');
  }

  Future<void> salvarChamados(
    int boardId,
    List<ChamadoManutencao> cards,
  ) async {
    final b = await box;

    final atuais = cards.map((c) => 'card:$boardId:${c.id}').toSet();

    // A resposta remota é a fonte de verdade
    // sobre quais cartões continuam ativos.
    for (final key in b.keys.toList()) {
      if (!'$key'.startsWith('card:$boardId:')) {
        continue;
      }

      if (atuais.contains('$key')) continue;

      final cardId = int.tryParse('$key'.split(':').last);

      await b.delete(key);

      if (cardId != null) {
        // Remove a finalização ativa, mas mantém
        // o histórico para detectar garantia.
        await b.delete('visita:$boardId:$cardId');
      }
    }

    for (final c in cards) {
      final chave = _chave(boardId, c.id);

      final tinhaHistorico = await historicoConclusao(boardId, c.id);

      final naoConformidade = DeckService.listaEncaminhada(c.nomeLista);

      final reaberto = tinhaHistorico && !c.concluido && naoConformidade;

      if (c.concluido) {
        await registrarHistorico(boardId, c.id);
      }

      if (reaberto) {
        await reabrirVisita(boardId, c.id);
      }

      final garantia =
          reaberto || (c.garantia && !c.concluido && naoConformidade);

      // Não deixar uma finalização local antiga
      // bloquear a nova visita em garantia.
      if (garantia) {
        await b.put('garantia:$chave', 'true');
      } else if (c.concluido) {
        await b.delete('garantia:$chave');
      }

      final garantiaPersistida = b.get('garantia:$chave') == 'true';

      await b.put(
        'card:$chave',
        jsonEncode({
          'id': c.id,
          'boardId': c.boardId,
          'stackId': c.stackId,
          'titulo': c.titulo,
          'descricao': c.descricao,
          'data': c.data?.toIso8601String(),
          'etiquetas': c.etiquetas,
          'concluido': c.concluido,
          'nomeLista': c.nomeLista,
          'garantia': garantiaPersistida && !c.concluido && naoConformidade,
        }),
      );
    }
  }

  Future<List<ChamadoManutencao>> chamados(int boardId) async {
    final b = await box;
    final resultado = <ChamadoManutencao>[];

    for (final key in b.keys) {
      if (!'$key'.startsWith('card:$boardId:')) {
        continue;
      }

      final valor = b.get(key);
      if (valor == null) continue;

      final m = jsonDecode(valor) as Map;

      resultado.add(
        ChamadoManutencao(
          id: (m['id'] as num).toInt(),
          boardId: (m['boardId'] as num).toInt(),
          stackId: (m['stackId'] as num).toInt(),
          titulo: '${m['titulo']}',
          descricao: '${m['descricao'] ?? ''}',
          data: m['data'] == null ? null : DateTime.tryParse('${m['data']}'),
          etiquetas: List<String>.from(m['etiquetas'] ?? []),
          concluido: m['concluido'] == true,
          nomeLista: '${m['nomeLista'] ?? ''}',
          garantia: m['garantia'] == true,
        ),
      );
    }

    resultado.sort((a, b) {
      if (a.concluido != b.concluido) {
        return a.concluido ? 1 : -1;
      }

      if (a.data == null && b.data == null) return 0;
      if (a.data == null) return 1;
      if (b.data == null) return -1;

      return a.data!.compareTo(b.data!);
    });

    return resultado;
  }

  Future<void> adicionarOperacao(OperacaoManutencao op) async {
    final b = await box;
    await b.put('op:${op.id}', jsonEncode(op.toJson()));
  }

  Future<List<OperacaoManutencao>> operacoes({
    int? boardId,
    int? cardId,
    bool somentePendentes = false,
  }) async {
    final b = await box;
    final resultado = <OperacaoManutencao>[];

    for (final key in b.keys) {
      if (!'$key'.startsWith('op:')) continue;

      final valor = b.get(key);
      if (valor == null) continue;

      final op = OperacaoManutencao.fromJson(jsonDecode(valor) as Map);

      if (boardId != null && op.boardId != boardId) {
        continue;
      }

      if (cardId != null && op.cardId != cardId) {
        continue;
      }

      if (somentePendentes && op.enviada) {
        continue;
      }

      resultado.add(op);
    }

    resultado.sort((a, b) => a.criadaEm.compareTo(b.criadaEm));

    return resultado;
  }

  Future<void> marcarEnviada(String id) async {
    final b = await box;
    final valor = b.get('op:$id');

    if (valor == null) return;

    final op = OperacaoManutencao.fromJson(jsonDecode(valor) as Map);

    await adicionarOperacao(op.enviado());
  }

  Future<void> finalizarVisita(int boardId, int cardId, DateTime data) async {
    final b = await box;

    await b.put('visita:${_chave(boardId, cardId)}', data.toIso8601String());

    await registrarHistorico(boardId, cardId);
  }

  Future<bool> visitaFinalizada(int boardId, int cardId) async {
    final b = await box;

    return b.containsKey('visita:${_chave(boardId, cardId)}');
  }

  Future<DateTime?> ultimaSincronizacao(int boardId) async {
    final b = await box;
    final valor = b.get('sync:$boardId');

    return valor == null ? null : DateTime.tryParse(valor);
  }

  Future<void> registrarSincronizacao(int boardId) async {
    final b = await box;

    await b.put('sync:$boardId', DateTime.now().toIso8601String());
  }

  Future<void> salvarComentarios(
    int boardId,
    int cardId,
    List<DeckComentario> dados,
  ) async {
    final b = await box;

    await b.put(
      'comments:$boardId:$cardId',
      jsonEncode([
        for (final c in dados)
          {
            'id': c.id,
            'autor': c.autor,
            'mensagem': c.mensagem,
            'data': c.data?.toIso8601String(),
          },
      ]),
    );
  }

  Future<List<DeckComentario>> comentarios(int boardId, int cardId) async {
    final b = await box;
    final valor = b.get('comments:$boardId:$cardId');

    if (valor == null) return [];

    return (jsonDecode(valor) as List).map((item) {
      final m = item as Map;

      return DeckComentario(
        id: '${m['id']}',
        autor: '${m['autor']}',
        mensagem: '${m['mensagem']}',
        data: m['data'] == null ? null : DateTime.tryParse('${m['data']}'),
      );
    }).toList();
  }

  Future<void> salvarAnexos(
    int boardId,
    int cardId,
    List<DeckAnexo> dados,
  ) async {
    final b = await box;

    await b.put(
      'attachments:$boardId:$cardId',
      jsonEncode([
        for (final a in dados) {'id': a.id, 'nome': a.nome, 'tipo': a.tipo},
      ]),
    );
  }

  Future<List<DeckAnexo>> anexos(int boardId, int cardId) async {
    final b = await box;
    final valor = b.get('attachments:$boardId:$cardId');

    if (valor == null) return [];

    return (jsonDecode(valor) as List).map((item) {
      final m = item as Map;

      return DeckAnexo(
        id: (m['id'] as num).toInt(),
        nome: '${m['nome']}',
        tipo: '${m['tipo']}',
      );
    }).toList();
  }

  Future<String> guardarMidia(String temporario, String nome) async {
    final raiz = await getApplicationDocumentsDirectory();

    final pasta = Directory('${raiz.path}/billhard_manutencao/$_uid');

    await pasta.create(recursive: true);

    final destino = File('${pasta.path}/$nome');

    await File(temporario).copy(destino.path);

    return destino.path;
  }

  Future<void> excluirMidia(String caminho) async {
    final raiz = await getApplicationDocumentsDirectory();

    final prefixo = '${raiz.path}/billhard_manutencao/$_uid/';

    if (!caminho.startsWith(prefixo)) return;

    final arquivo = File(caminho);

    if (await arquivo.exists()) {
      await arquivo.delete();
    }
  }

  Future<void> salvarAvisoSync(int boardId, String mensagem) async {
    final b = await box;

    await b.put(
      'aviso_sync:$boardId',
      jsonEncode({
        'mensagem': mensagem,
        'data': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> removerPendencia(String operacaoId) async {
    final b = await box;

    final chave = 'op:$operacaoId';
    final valor = b.get(chave);

    if (valor == null) return;

    final op = OperacaoManutencao.fromJson(jsonDecode(valor) as Map);

    if (op.enviada) return;

    await b.delete(chave);
  }

  Future<String?> avisoSync(int boardId) async {
    final b = await box;
    final valor = b.get('aviso_sync:$boardId');

    if (valor == null) return null;

    try {
      final dados = jsonDecode(valor) as Map;
      return '${dados['mensagem'] ?? ''}';
    } catch (_) {
      return valor;
    }
  }

  Future<void> limparAvisoSync(int boardId) async {
    final b = await box;
    await b.delete('aviso_sync:$boardId');
  }
}
