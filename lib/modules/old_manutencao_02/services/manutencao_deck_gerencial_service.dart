import 'dart:convert';
import 'package:http/http.dart' as http;
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

  Future<List<DeckChamadoGerencial>> listar() async {
    final c = await configuracao();

    final stacks = await _request(c, 'GET', 'boards/${c.quadroId}/stacks');

    if (stacks is! List) {
      throw StateError('Listas inválidas do Deck.');
    }

    final resultado = <DeckChamadoGerencial>[];

    for (final stack in stacks.whereType<Map>()) {
      final lista = '${stack['title'] ?? ''}';

      final cards = stack['cards'] is List ? stack['cards'] as List : const [];

      for (final card in cards.whereType<Map>()) {
        if (card['archived'] == true || card['deletedAt'] != null) {
          continue;
        }

        final users = card['assignedUsers'];
        final tecnicos = <String>[];

        if (users is List) {
          for (final u in users.whereType<Map>()) {
            final p = u['participant'];

            if (p is Map) {
              tecnicos.add(
                '${p['displayname'] ?? p['displayName'] ?? p['uid'] ?? 'Não identificado'}',
              );
            }
          }
        }

        final due = card['duedate'] ?? card['dueDate'];

        resultado.add(
          DeckChamadoGerencial(
            int.tryParse('${card['id']}') ?? 0,
            '${card['title'] ?? 'Sem título'}',
            '${card['description'] ?? ''}',
            lista,
            tecnicos.isEmpty ? 'Não atribuído' : tecnicos.join(', '),
            due == null ? null : DateTime.tryParse('$due')?.toLocal(),
            _opcoes(card['labels']),
            lista.toLowerCase().contains('conclu') ||
                (card['done'] != null &&
                    card['done'] != false &&
                    card['done'] != 0),
          ),
        );
      }
    }

    return resultado.where((c) => c.id > 0).toList();
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
