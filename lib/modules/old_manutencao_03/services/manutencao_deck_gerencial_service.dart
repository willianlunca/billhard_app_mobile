import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nextcloud_config_service.dart';

class DeckOpcao {
  final int id;
  final String nome;
  final String cor;

  const DeckOpcao(this.id, this.nome, this.cor);
}

class DeckChamadoGerencial {
  final int id;
  final String titulo;
  final String descricao;
  final String lista;
  final String tecnico;
  final DateTime? vencimento;
  final List<DeckOpcao> etiquetas;
  final bool concluido;

  const DeckChamadoGerencial(
    this.id,
    this.titulo,
    this.descricao,
    this.lista,
    this.tecnico,
    this.vencimento,
    this.etiquetas,
    this.concluido,
  );
}

class ManutencaoDeckGerencialService {
  final _config = NextcloudConfigService();
  final _http = http.Client();

  void dispose() => _http.close();

  Future<NextcloudConfig> configuracao() async {
    final c = await _config.carregar();

    if (c == null || c.quadroId == null) {
      throw StateError('Configure a conexão e o quadro Nextcloud.');
    }

    return c;
  }

  Future<dynamic> _request(
    NextcloudConfig c,
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final base = Uri.parse(c.url);

    if (base.scheme != 'https' || base.userInfo.isNotEmpty) {
      throw StateError('URL HTTPS inválida.');
    }

    final prefix = base.path.replaceFirst(RegExp(r'/$'), '');

    final uri = base.replace(
      path: '$prefix/index.php/apps/deck/api/v1.0/$path',
    );

    final token = base64Encode(utf8.encode('${c.usuario}:${c.senha}'));

    final req = http.Request(method, uri)
      ..headers.addAll({
        'Authorization': 'Basic $token',
        'OCS-APIRequest': 'true',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      });

    if (body != null) {
      req.body = jsonEncode(body);
    }

    final resp = await http.Response.fromStream(
      await _http.send(req).timeout(const Duration(seconds: 30)),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Nextcloud HTTP ${resp.statusCode}: '
        '${utf8.decode(resp.bodyBytes)}',
      );
    }

    if (resp.bodyBytes.isEmpty) return null;

    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  List<DeckOpcao> _opcoes(dynamic items) {
    if (items is! List) return [];

    return items
        .whereType<Map>()
        .map(
          (e) => DeckOpcao(
            int.tryParse('${e['id']}') ?? 0,
            '${e['title'] ?? e['name'] ?? ''}',
            '${e['color'] ?? ''}',
          ),
        )
        .where((e) => e.id > 0)
        .toList();
  }

  Future<List<DeckOpcao>> etiquetas() async {
    final c = await configuracao();

    final board = await _request(c, 'GET', 'boards/${c.quadroId}');

    return _opcoes(board is Map ? board['labels'] : null);
  }

  Future<List<DeckOpcao>> listas() async {
    final c = await configuracao();

    final stacks = await _request(c, 'GET', 'boards/${c.quadroId}/stacks');

    if (stacks is! List) return [];

    return _opcoes(stacks);
  }

  // A consulta de stacks pode retornar cartões omitidos ou incompletos.
  // Consultamos os cartões de cada lista explicitamente.
  Future<List<DeckChamadoGerencial>> listar() async {
    final c = await configuracao();
    final stacks = await _request(c, 'GET', 'boards/${c.quadroId}/stacks');
    if (stacks is! List) throw StateError('Resposta inválida das listas do Deck.');
    final resultado = <DeckChamadoGerencial>[];
    for (final stack in stacks.whereType<Map>()) {
      final stackId = int.tryParse('${stack['id']}');
      if (stackId == null) continue;
      final lista = '${stack['title'] ?? ''}';
      final cards = await _request(c, 'GET', 'boards/${c.quadroId}/stacks/$stackId/cards');
      if (cards is! List) throw StateError('Cartões inválidos na lista $lista.');
      for (final card in cards.whereType<Map>()) {
        if (card['archived'] == true || card['deletedAt'] != null) continue;
        final id = int.tryParse('${card['id']}');
        if (id == null) continue;
        final nomes = <String>[];
        if (card['assignedUsers'] is List) {
          for (final item in (card['assignedUsers'] as List).whereType<Map>()) {
            final p = item['participant'];
            if (p is Map) nomes.add('${p['displayname'] ?? p['displayName'] ?? p['uid'] ?? p['primaryKey'] ?? 'Usuário'}');
          }
        }
        final due = card['duedate'] ?? card['dueDate'];
        final done = card['done'];
        resultado.add(DeckChamadoGerencial(
          id, '${card['title'] ?? 'Sem título'}', '${card['description'] ?? ''}',
          lista, nomes.isEmpty ? 'Não atribuído' : nomes.join(', '),
          due == null ? null : DateTime.tryParse('$due')?.toLocal(),
          _opcoes(card['labels']),
          lista.toLowerCase().contains('conclu') ||
          (done != null && done != false && done != 0 && done != ''),
        ));
      }
    }
    return resultado;
  }

  Future<List<Map<String, dynamic>>> comentarios(int cardId) async {
    final c = await configuracao();
    final resultado = <Map<String, dynamic>>[];
    const limite = 100;
    for (var offset = 0; offset < 1000; offset += limite) {
      final resposta = await _requestOcs(c,
        'ocs/v2.php/apps/deck/api/v1.0/cards/$cardId/comments?limit=$limite&offset=$offset');
      final dados = resposta is Map && resposta['ocs'] is Map
          ? (resposta['ocs'] as Map)['data'] : resposta;
      if (dados is! List) throw StateError('Comentários inválidos do cartão $cardId');
      resultado.addAll(dados.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      if (dados.length < limite) break;
    }
    return resultado;
  }

  Future<dynamic> _requestOcs(NextcloudConfig c, String path) async {
    final base = Uri.parse(c.url);
    if (base.scheme != 'https' || base.userInfo.isNotEmpty) throw StateError('URL HTTPS inválida.');
    final prefix = base.path.replaceFirst(RegExp(r'/$'), '');
    final uri = base.replace(path: '$prefix/$path');
    final response = await _http.get(uri, headers: {
      'Authorization': 'Basic ${base64Encode(utf8.encode('${c.usuario}:${c.senha}'))}',
      'OCS-APIRequest': 'true', 'Accept': 'application/json',
    }).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Comentários: HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<String> _cacheKey() async {
    final c = await configuracao();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    return 'billhard_chamados_${userId}_${Uri.parse(c.url).host}_${c.usuario}_${c.quadroId}';
  }

  Future<List<DeckChamadoGerencial>> carregarCache() async {
    final key = await _cacheKey();
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return [];
    final data = jsonDecode(raw);
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => DeckChamadoGerencial(
      (e['id'] as num).toInt(), '${e['titulo']}', '${e['descricao']}',
      '${e['lista']}', '${e['tecnico']}',
      e['vencimento'] == null ? null : DateTime.tryParse('${e['vencimento']}'),
      (e['etiquetas'] as List? ?? []).whereType<Map>().map((v) => DeckOpcao(
        (v['id'] as num).toInt(), '${v['nome']}', '${v['cor']}')).toList(),
      e['concluido'] == true,
    )).toList();
  }

  Future<void> salvarCache(List<DeckChamadoGerencial> cards) async {
    final key = await _cacheKey();
    final data = cards.map((c) => {
      'id': c.id, 'titulo': c.titulo, 'descricao': c.descricao,
      'lista': c.lista, 'tecnico': c.tecnico,
      'vencimento': c.vencimento?.toIso8601String(), 'concluido': c.concluido,
      'etiquetas': c.etiquetas.map((e) => {'id': e.id, 'nome': e.nome, 'cor': e.cor}).toList(),
    }).toList();
    await (await SharedPreferences.getInstance()).setString(key, jsonEncode(data));
  }

  Future<List<Map<String, dynamic>>> carregarComentariosCache(int cardId) async {
    final key = '${await _cacheKey()}_comments_$cardId';
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> salvarComentariosCache(int cardId, List<Map<String, dynamic>> dados) async {
    final key = '${await _cacheKey()}_comments_$cardId';
    await (await SharedPreferences.getInstance()).setString(key, jsonEncode(dados));
  }

  Future<void> criar({
    required String titulo,
    required String descricao,
    required int stackId,
    required int prioridadeId,
  }) async {
    final c = await configuracao();

    if (prioridadeId <= 0) {
      throw ArgumentError.value(
        prioridadeId,
        'prioridadeId',
        'Selecione uma etiqueta válida.',
      );
    }

    // Cria o cartão na lista selecionada.
    final criado = await _request(
      c,
      'POST',
      'boards/${c.quadroId}/stacks/$stackId/cards',
      {
        'title': titulo,
        'description': descricao,
        'type': 'plain',
        'order': 999,
      },
    );

    final cardId = criado is Map ? int.tryParse('${criado['id']}') : null;

    if (cardId == null || cardId <= 0) {
      throw StateError(
        'O cartão foi criado, mas o Deck não retornou '
        'seu ID. Verifique o cartão antes de tentar novamente.',
      );
    }

    // Associa a etiqueta de prioridade diretamente ao cartão.
    try {
      await _request(
        c,
        'PUT',
        'boards/${c.quadroId}/stacks/$stackId/cards/$cardId/assignLabel',
        {'labelId': prioridadeId},
      );
    } catch (e) {
      throw StateError(
        'O cartão #$cardId foi criado, mas não foi possível '
        'atribuir a etiqueta. Não envie novamente antes '
        'de verificar o cartão no Deck. Erro: $e',
      );
    }
  }
}
