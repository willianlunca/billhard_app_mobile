import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nextcloud_config_service.dart';

// ============================================================
// MODELOS
// ============================================================

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

// ============================================================
// SERVIÇO GERENCIAL DE MANUTENÇÃO
// ============================================================

class ManutencaoDeckGerencialService {
  final _config = NextcloudConfigService();
  final _http = http.Client();

  void dispose() => _http.close();

  // ============================================================
  // CONFIGURAÇÃO
  // ============================================================

  Future<NextcloudConfig> configuracao() async {
    final c = await _config.carregar();

    if (c == null || c.quadroId == null) {
      throw StateError('Configure a conexão e o quadro Nextcloud.');
    }

    return c;
  }

  // ============================================================
  // URL E AUTENTICAÇÃO
  // ============================================================

  Uri _montarUrl(NextcloudConfig c, String caminho) {
    final base = Uri.parse(c.url.trim());

    if (base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw StateError('URL HTTPS inválida.');
    }

    // IMPORTANTE:
    // O caminho e os parâmetros da consulta devem ser
    // tratados separadamente.
    //
    // Exemplo:
    // cards/113/comments?limit=100&offset=0
    //
    // O '?' não pode ser codificado como parte do path.

    final endpoint = Uri.parse(caminho);
    final prefixo = base.path.replaceFirst(RegExp(r'/$'), '');

    return base.replace(
      path: '$prefixo/${endpoint.path}',
      query: endpoint.hasQuery ? endpoint.query : null,
      fragment: null,
    );
  }

  Map<String, String> _headers(NextcloudConfig c, {bool json = false}) {
    final token = base64Encode(utf8.encode('${c.usuario}:${c.senha}'));

    return {
      'Authorization': 'Basic $token',
      'OCS-APIRequest': 'true',
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
  }

  // ============================================================
  // REQUISIÇÕES DECK
  // ============================================================

  Future<dynamic> _request(
    NextcloudConfig c,
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = _montarUrl(c, 'index.php/apps/deck/api/v1.0/$path');

    final req = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll(_headers(c, json: body != null));

    if (body != null) {
      req.body = jsonEncode(body);
    }

    final streamed = await _http.send(req).timeout(const Duration(seconds: 30));

    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Nextcloud HTTP ${resp.statusCode} '
        'em ${uri.path}: '
        '${utf8.decode(resp.bodyBytes)}',
      );
    }

    if (resp.bodyBytes.isEmpty) {
      return null;
    }

    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  // ============================================================
  // REQUISIÇÕES OCS
  // ============================================================

  Future<dynamic> _requestOcs(NextcloudConfig c, String caminho) async {
    // CORREÇÃO PRINCIPAL:
    // _montarUrl separa corretamente path e query.

    final uri = _montarUrl(c, caminho);

    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll(_headers(c));

    final streamed = await _http
        .send(request)
        .timeout(const Duration(seconds: 30));

    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Comentários: HTTP ${response.statusCode}. '
        'Endpoint: ${uri.path}'
        '${uri.hasQuery ? '?${uri.query}' : ''}. '
        'Resposta: ${utf8.decode(response.bodyBytes)}',
      );
    }

    if (response.bodyBytes.isEmpty) {
      throw StateError(
        'O Nextcloud retornou uma resposta vazia '
        'ao consultar comentários.',
      );
    }

    final resposta = jsonDecode(utf8.decode(response.bodyBytes));

    // A API OCS encapsula os dados em:
    // { "ocs": { "meta": {...}, "data": [...] } }

    if (resposta is Map && resposta['ocs'] is Map) {
      final ocs = resposta['ocs'] as Map;
      final meta = ocs['meta'];

      if (meta is Map) {
        final statuscode = int.tryParse('${meta['statuscode']}');

        if (statuscode != null && statuscode >= 400) {
          throw StateError(
            'Comentários: erro OCS $statuscode: '
            '${meta['message'] ?? 'Erro desconhecido'}',
          );
        }
      }
    }

    return resposta;
  }

  // ============================================================
  // CONVERSÃO DE ETIQUETAS E LISTAS
  // ============================================================

  List<DeckOpcao> _opcoes(dynamic items) {
    if (items is! List) {
      return [];
    }

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

    if (stacks is! List) {
      return [];
    }

    return _opcoes(stacks);
  }

  // ============================================================
  // LISTAGEM GERENCIAL DOS CHAMADOS
  // ============================================================

  Future<List<DeckChamadoGerencial>> listar() async {
    final c = await configuracao();

    final stacks = await _request(c, 'GET', 'boards/${c.quadroId}/stacks');

    if (stacks is! List) {
      throw StateError('Resposta inválida das listas do Deck.');
    }

    final resultado = <DeckChamadoGerencial>[];

    for (final stack in stacks.whereType<Map>()) {
      final stackId = int.tryParse('${stack['id']}');

      if (stackId == null) {
        continue;
      }

      final lista = '${stack['title'] ?? ''}';

      // O Nextcloud retorna os cartões dentro das listas.
      // Algumas listas podem retornar cards = null.
      // Isso não deve interromper as demais listas.

      final cards = stack['cards'];

      if (cards == null) {
        continue;
      }

      if (cards is! List) {
        throw StateError(
          'Formato inválido dos cartões '
          'da lista "$lista".',
        );
      }

      for (final card in cards.whereType<Map>()) {
        final archived = card['archived'] == true;

        final deletedAt = card['deletedAt'];

        // No Nextcloud, deletedAt = 0 significa
        // que o cartão NÃO foi excluído.

        final excluido =
            deletedAt != null &&
            deletedAt != 0 &&
            deletedAt != '0' &&
            deletedAt != false &&
            deletedAt != '';

        if (archived || excluido) {
          continue;
        }

        final id = int.tryParse('${card['id']}');

        if (id == null) {
          continue;
        }

        // ------------------------------------------------------
        // TÉCNICOS RESPONSÁVEIS
        // ------------------------------------------------------

        final nomes = <String>[];

        if (card['assignedUsers'] is List) {
          final atribuicoes = card['assignedUsers'] as List;

          for (final item in atribuicoes.whereType<Map>()) {
            final participante = item['participant'];

            if (participante is Map) {
              nomes.add(
                '${participante['displayname'] ?? participante['displayName'] ?? participante['uid'] ?? participante['primaryKey'] ?? 'Usuário'}',
              );
            }
          }
        }

        // ------------------------------------------------------
        // PRAZO E CONCLUSÃO
        // ------------------------------------------------------

        final due = card['duedate'] ?? card['dueDate'];

        final done = card['done'];

        final concluido =
            lista.toLowerCase().contains('conclu') ||
            (done != null && done != false && done != 0 && done != '');

        // ------------------------------------------------------
        // RESULTADO
        // ------------------------------------------------------

        resultado.add(
          DeckChamadoGerencial(
            id,
            '${card['title'] ?? 'Sem título'}',
            '${card['description'] ?? ''}',
            lista,
            nomes.isEmpty ? 'Não atribuído' : nomes.join(', '),
            due == null ? null : DateTime.tryParse('$due')?.toLocal(),
            _opcoes(card['labels']),
            concluido,
          ),
        );
      }
    }

    return resultado;
  }

  // ============================================================
  // COMENTÁRIOS
  // ============================================================

  Future<List<Map<String, dynamic>>> comentarios(int cardId) async {
    if (cardId <= 0) {
      throw ArgumentError.value(
        cardId,
        'cardId',
        'Identificador inválido do cartão.',
      );
    }

    final c = await configuracao();

    final resultado = <Map<String, dynamic>>[];

    const limite = 100;

    // Mantém a paginação utilizada no serviço
    // original de Minha Agenda, mas com implementação
    // HTTP própria deste serviço gerencial.

    for (var offset = 0; offset < 1000; offset += limite) {
      final resposta = await _requestOcs(
        c,
        'ocs/v2.php/apps/deck/api/v1.0/'
        'cards/$cardId/comments'
        '?limit=$limite&offset=$offset',
      );

      final dados = resposta is Map && resposta['ocs'] is Map
          ? (resposta['ocs'] as Map)['data']
          : resposta;

      if (dados is! List) {
        throw StateError('Comentários inválidos do cartão #$cardId.');
      }

      for (final item in dados.whereType<Map>()) {
        final comentario = Map<String, dynamic>.from(item);

        // Preserva os campos originais da API.
        // Garante compatibilidade com a apresentação
        // dos comentários na tela de detalhes.

        final dataTexto =
            comentario['creationDateTime'] ?? comentario['datetime'];

        comentario['id'] = '${comentario['id'] ?? ''}';

        comentario['actorDisplayName'] =
            '${comentario['actorDisplayName'] ?? comentario['actorId'] ?? 'Usuário'}';

        comentario['message'] = '${comentario['message'] ?? ''}';

        if (dataTexto != null) {
          comentario['creationDateTime'] = '$dataTexto';
        }

        resultado.add(comentario);
      }

      if (dados.length < limite) {
        break;
      }
    }

    return resultado;
  }

  // ============================================================
  // CHAVE DO CACHE
  // ============================================================

  Future<String> _cacheKey() async {
    final c = await configuracao();

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';

    return 'billhard_chamados_'
        '${userId}_'
        '${Uri.parse(c.url).host}_'
        '${c.usuario}_'
        '${c.quadroId}';
  }

  // ============================================================
  // CACHE OFFLINE DOS CHAMADOS
  // ============================================================

  Future<List<DeckChamadoGerencial>> carregarCache() async {
    final key = await _cacheKey();

    final raw = (await SharedPreferences.getInstance()).getString(key);

    if (raw == null) {
      return [];
    }

    final data = jsonDecode(raw);

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map(
          (e) => DeckChamadoGerencial(
            (e['id'] as num).toInt(),
            '${e['titulo']}',
            '${e['descricao']}',
            '${e['lista']}',
            '${e['tecnico']}',
            e['vencimento'] == null
                ? null
                : DateTime.tryParse('${e['vencimento']}'),
            (e['etiquetas'] as List? ?? [])
                .whereType<Map>()
                .map(
                  (v) => DeckOpcao(
                    (v['id'] as num).toInt(),
                    '${v['nome']}',
                    '${v['cor']}',
                  ),
                )
                .toList(),
            e['concluido'] == true,
          ),
        )
        .toList();
  }

  Future<void> salvarCache(List<DeckChamadoGerencial> cards) async {
    final key = await _cacheKey();

    final data = cards
        .map(
          (c) => {
            'id': c.id,
            'titulo': c.titulo,
            'descricao': c.descricao,
            'lista': c.lista,
            'tecnico': c.tecnico,
            'vencimento': c.vencimento?.toIso8601String(),
            'concluido': c.concluido,
            'etiquetas': c.etiquetas
                .map((e) => {'id': e.id, 'nome': e.nome, 'cor': e.cor})
                .toList(),
          },
        )
        .toList();

    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(data),
    );
  }

  // ============================================================
  // CACHE OFFLINE DOS COMENTÁRIOS
  // ============================================================

  Future<List<Map<String, dynamic>>> carregarComentariosCache(
    int cardId,
  ) async {
    final key = '${await _cacheKey()}_comments_$cardId';

    final raw = (await SharedPreferences.getInstance()).getString(key);

    if (raw == null) {
      return [];
    }

    final data = jsonDecode(raw);

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> salvarComentariosCache(
    int cardId,
    List<Map<String, dynamic>> dados,
  ) async {
    final key = '${await _cacheKey()}_comments_$cardId';

    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(dados),
    );
  }

  // ============================================================
  // CRIAÇÃO DE CHAMADOS
  // ============================================================

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

    // ----------------------------------------------------------
    // CRIAÇÃO DO CARTÃO
    // ----------------------------------------------------------

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
        'seu ID. Verifique o cartão antes de tentar '
        'novamente.',
      );
    }

    // ----------------------------------------------------------
    // ATRIBUIÇÃO DA ETIQUETA DE PRIORIDADE
    // ----------------------------------------------------------

    try {
      await _request(
        c,
        'PUT',
        'boards/${c.quadroId}/stacks/'
            '$stackId/cards/$cardId/assignLabel',
        {'labelId': prioridadeId},
      );
    } catch (e) {
      throw StateError(
        'O cartão #$cardId foi criado, mas não foi '
        'possível atribuir a etiqueta. '
        'Não envie novamente antes de verificar '
        'o cartão no Deck. Erro: $e',
      );
    }
  }
}
