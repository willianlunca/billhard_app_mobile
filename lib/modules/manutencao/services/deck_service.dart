import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'nextcloud_config_service.dart';

// ============================================================
// MODELOS
// ============================================================

class DeckQuadro {
  final int id;
  final String nome;

  const DeckQuadro({required this.id, required this.nome});
}

class ChamadoManutencao {
  final int id;
  final int boardId;
  final int stackId;
  final String titulo;
  final String descricao;
  final DateTime? data;
  final List<String> etiquetas;
  final bool concluido;
  final String nomeLista;
  final bool garantia;

  const ChamadoManutencao({
    required this.id,
    required this.boardId,
    required this.stackId,
    required this.titulo,
    required this.descricao,
    required this.data,
    required this.etiquetas,
    required this.concluido,
    this.nomeLista = '',
    this.garantia = false,
  });
}

class DeckComentario {
  final String id;
  final String autor;
  final String mensagem;
  final DateTime? data;

  const DeckComentario({
    required this.id,
    required this.autor,
    required this.mensagem,
    required this.data,
  });
}

class DeckAnexo {
  final int id;
  final String nome;
  final String tipo;

  const DeckAnexo({required this.id, required this.nome, required this.tipo});
}

class NextcloudNaoConfiguradoException implements Exception {
  const NextcloudNaoConfiguradoException();

  @override
  String toString() => 'Configure sua conexão Nextcloud pela engrenagem.';
}

class NextcloudQuadroNaoConfiguradoException implements Exception {
  const NextcloudQuadroNaoConfiguradoException();

  @override
  String toString() => 'Selecione um quadro nas configurações do Nextcloud.';
}

// ============================================================
// SERVIÇO DECK
// ============================================================

class DeckService {
  DeckService({NextcloudConfigService? configuracoes, http.Client? client})
    : _configuracoes = configuracoes ?? NextcloudConfigService(),
      _client = client ?? http.Client();

  final NextcloudConfigService _configuracoes;
  final http.Client _client;

  // ============================================================
  // CONFIGURAÇÃO E AUTENTICAÇÃO
  // ============================================================

  Uri _base(NextcloudConfig config) {
    final uri = Uri.tryParse(config.url.trim());

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Informe uma URL HTTPS válida do Nextcloud.');
    }

    return uri;
  }

  Uri _url(NextcloudConfig config, String caminho) {
    final base = _base(config);
    final prefixo = base.path.replaceAll(RegExp(r'/$'), '');
    final endpoint = Uri.parse(caminho);

    return base.replace(
      path: '$prefixo/${endpoint.path}',
      query: endpoint.hasQuery ? endpoint.query : null,
      fragment: null,
    );
  }

  Map<String, String> _headers(NextcloudConfig config) {
    final auth = base64Encode(utf8.encode('${config.usuario}:${config.senha}'));

    return {
      'Authorization': 'Basic $auth',
      'OCS-APIRequest': 'true',
      'Accept': 'application/json',
    };
  }

  Future<NextcloudConfig> _config() async {
    final config = await _configuracoes.carregar();

    if (config == null) {
      throw const NextcloudNaoConfiguradoException();
    }

    return config;
  }

  // ============================================================
  // HTTP
  // ============================================================

  Future<http.Response> _enviar(
    NextcloudConfig config,
    String metodo,
    String caminho, {
    Map<String, dynamic>? dados,
  }) async {
    final request = http.Request(metodo, _url(config, caminho));

    request.followRedirects = false;
    request.headers.addAll(_headers(config));

    if (dados != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(dados);
    }

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));

    final response = await http.Response.fromStream(streamed);

    _verificarResposta(response, caminho);

    return response;
  }

  void _verificarResposta(http.Response response, String caminho) {
    final status = response.statusCode;

    if (status >= 300 && status < 400) {
      throw StateError(
        'O Nextcloud redirecionou a requisição '
        '$caminho. Confira a URL configurada.',
      );
    }

    if (status == 401) {
      throw StateError(
        'Autenticação recusada pelo Nextcloud '
        'em $caminho (HTTP 401).',
      );
    }

    if (status == 403) {
      throw StateError(
        'Permissão negada pelo Nextcloud '
        'em $caminho (HTTP 403).',
      );
    }

    if (status < 200 || status >= 300) {
      throw StateError(
        'Erro HTTP $status em $caminho. '
        '${_mensagemErro(response)}',
      );
    }
  }

  String _mensagemErro(http.Response response) {
    try {
      final dados = jsonDecode(utf8.decode(response.bodyBytes));

      if (dados is Map) {
        final ocs = dados['ocs'];

        if (ocs is Map && ocs['meta'] is Map) {
          return '${ocs['meta']['message'] ?? ''}';
        }

        return '${dados['message'] ?? ''}';
      }
    } catch (_) {
      // Mantém o erro HTTP original.
    }

    return '';
  }

  Future<dynamic> _json(
    NextcloudConfig config,
    String metodo,
    String caminho, {
    Map<String, dynamic>? dados,
  }) async {
    final response = await _enviar(config, metodo, caminho, dados: dados);

    if (response.bodyBytes.isEmpty) {
      return null;
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  dynamic _ocsData(dynamic resposta) {
    if (resposta is Map && resposta['ocs'] is Map) {
      final ocs = resposta['ocs'] as Map;
      final meta = ocs['meta'];

      if (meta is Map) {
        final codigo = int.tryParse('${meta['statuscode']}');

        if (codigo != null && codigo >= 400) {
          throw StateError(
            'Erro OCS $codigo: '
            '${meta['message'] ?? 'Erro desconhecido'}',
          );
        }
      }

      return ocs['data'];
    }

    return resposta;
  }

  // ============================================================
  // UTILITÁRIOS
  // ============================================================

  int? _inteiro(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse('$valor');
  }

  bool _excluido(dynamic valor) {
    if (valor == null) return false;

    if (valor is num) {
      return valor != 0;
    }

    final texto = '$valor'.trim();

    return texto.isNotEmpty && texto != '0' && texto.toLowerCase() != 'null';
  }

  bool _temConclusao(dynamic valor) {
    if (valor == null || valor == false) {
      return false;
    }

    if (valor is String) {
      return valor.trim().isNotEmpty;
    }

    return true;
  }

  String _normalizar(String valor) {
    return valor
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }

  bool _listaConcluida(String nome) {
    final texto = _normalizar(nome);

    return texto.contains('concluido') ||
        texto.contains('finalizado') ||
        texto.contains('finalizada');
  }

  bool _listaEncaminhada(String nome) {
    return _normalizar(nome).contains('nao conformidade');
  }

  // Método público utilizado por outros serviços.
  static bool listaEncaminhada(String nome) {
    final normalizado = nome
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');

    return normalizado.contains('nao conformidade');
  }

  String _caminhoCartao(ChamadoManutencao chamado) {
    return 'index.php/apps/deck/api/v1.1/'
        'boards/${chamado.boardId}/'
        'stacks/${chamado.stackId}/'
        'cards/${chamado.id}';
  }

  String _caminhoCartaoIds({
    required int boardId,
    required int stackId,
    required int cardId,
  }) {
    return 'index.php/apps/deck/api/v1.1/'
        'boards/$boardId/'
        'stacks/$stackId/'
        'cards/$cardId';
  }

  // ============================================================
  // QUADROS
  // ============================================================

  Future<List<DeckQuadro>> listarQuadros(NextcloudConfig config) async {
    final dados = await _json(
      config,
      'GET',
      'index.php/apps/deck/api/v1.0/boards',
    );

    if (dados is! List) {
      throw const FormatException('Resposta inválida da lista de quadros.');
    }

    final quadros = <DeckQuadro>[];

    for (final item in dados) {
      if (item is! Map) continue;
      if (item['archived'] == true) continue;
      if (_excluido(item['deletedAt'])) continue;

      final id = _inteiro(item['id']);

      if (id == null) continue;

      quadros.add(DeckQuadro(id: id, nome: '${item['title'] ?? 'Quadro $id'}'));
    }

    quadros.sort(
      (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
    );

    return quadros;
  }

  Future<void> testarConexao(NextcloudConfig config) async {
    await listarQuadros(config);
  }

  Future<String> _usuarioInterno(NextcloudConfig config) async {
    final resposta = await _json(
      config,
      'GET',
      'ocs/v2.php/cloud/user?format=json',
    );

    final dados = _ocsData(resposta);

    if (dados is! Map || dados['id'] == null || '${dados['id']}'.isEmpty) {
      throw StateError('Não foi possível identificar o usuário Nextcloud.');
    }

    return '${dados['id']}';
  }

  // ============================================================
  // LISTAS E CARTÕES
  // ============================================================

  Future<List<dynamic>> _buscarListas(
    NextcloudConfig config,
    int boardId,
  ) async {
    final resposta = await _json(
      config,
      'GET',
      'index.php/apps/deck/api/v1.0/'
          'boards/$boardId/stacks',
    );

    if (resposta is! List) {
      throw StateError('O Deck não retornou as listas do quadro $boardId.');
    }

    return resposta;
  }

  bool _atribuido(Map card, String usuarioId) {
    final atribuicoes = card['assignedUsers'];

    if (atribuicoes is! List) {
      return false;
    }

    for (final atribuicao in atribuicoes) {
      if (atribuicao is! Map) continue;

      final participante = atribuicao['participant'];

      if (participante is! Map) continue;

      if ('${participante['uid']}' == usuarioId ||
          '${participante['primaryKey']}' == usuarioId) {
        return true;
      }
    }

    return false;
  }

  List<String> _etiquetas(dynamic valor) {
    if (valor is! List) return [];

    return valor
        .whereType<Map>()
        .map((item) => '${item['title'] ?? item['name'] ?? ''}')
        .where((nome) => nome.isNotEmpty)
        .toList();
  }

  ChamadoManutencao? _converterCartao(
    Map card, {
    required int boardId,
    required int stackId,
    required String nomeLista,
  }) {
    if (card['archived'] == true) {
      return null;
    }

    if (_excluido(card['deletedAt'])) {
      return null;
    }

    final id = _inteiro(card['id']);

    if (id == null) return null;

    final concluido = _listaConcluida(nomeLista) || _temConclusao(card['done']);

    final dataTexto = card['duedate'] ?? card['dueDate'];

    return ChamadoManutencao(
      id: id,
      boardId: boardId,
      stackId: stackId,
      titulo: '${card['title'] ?? 'Sem título'}',
      descricao: '${card['description'] ?? ''}',
      data: dataTexto == null
          ? null
          : DateTime.tryParse('$dataTexto')?.toLocal(),
      etiquetas: _etiquetas(card['labels']),
      concluido: concluido,
      nomeLista: nomeLista,
      garantia:
          !concluido &&
          _listaEncaminhada(nomeLista) &&
          _temConclusao(card['done']),
    );
  }

  Future<List<ChamadoManutencao>> buscarMeusChamados() async {
    final config = await _config();

    if (config.quadroId == null) {
      throw const NextcloudQuadroNaoConfiguradoException();
    }

    final usuarioId = await _usuarioInterno(config);

    final listas = await _buscarListas(config, config.quadroId!);

    final chamados = <ChamadoManutencao>[];

    for (final lista in listas) {
      if (lista is! Map) continue;

      if (_excluido(lista['deletedAt'])) {
        continue;
      }

      final stackId = _inteiro(lista['id']);

      if (stackId == null) continue;

      final nomeLista = '${lista['title'] ?? ''}';
      final cartoes = lista['cards'];

      if (cartoes is! List) continue;

      for (final card in cartoes) {
        if (card is! Map) continue;

        if (!_atribuido(card, usuarioId)) {
          continue;
        }

        final chamado = _converterCartao(
          card,
          boardId: config.quadroId!,
          stackId: stackId,
          nomeLista: nomeLista,
        );

        if (chamado != null) {
          chamados.add(chamado);
        }
      }
    }

    chamados.sort((a, b) {
      if (a.concluido != b.concluido) {
        return a.concluido ? 1 : -1;
      }

      if (a.data == null && b.data == null) {
        return 0;
      }

      if (a.data == null) return 1;
      if (b.data == null) return -1;

      return a.data!.compareTo(b.data!);
    });

    return chamados;
  }

  Future<ChamadoManutencao?> localizarCartao(int boardId, int cardId) async {
    final config = await _config();
    final listas = await _buscarListas(config, boardId);

    for (final lista in listas) {
      if (lista is! Map) continue;

      if (_excluido(lista['deletedAt'])) {
        continue;
      }

      final stackId = _inteiro(lista['id']);

      if (stackId == null) continue;

      final nomeLista = '${lista['title'] ?? ''}';
      final cartoes = lista['cards'];

      if (cartoes is! List) continue;

      for (final card in cartoes) {
        if (card is! Map) continue;

        if (_inteiro(card['id']) != cardId) {
          continue;
        }

        return _converterCartao(
          card,
          boardId: boardId,
          stackId: stackId,
          nomeLista: nomeLista,
        );
      }
    }

    return null;
  }

  // ============================================================
  // COMENTÁRIOS
  // ============================================================

  Future<List<DeckComentario>> listarComentarios(
    ChamadoManutencao chamado,
  ) async {
    final config = await _config();
    final comentarios = <DeckComentario>[];

    const limite = 100;

    for (var offset = 0; ; offset += limite) {
      final resposta = await _json(
        config,
        'GET',
        'ocs/v2.php/apps/deck/api/v1.0/'
            'cards/${chamado.id}/comments'
            '?limit=$limite&offset=$offset',
      );

      final dados = _ocsData(resposta);

      if (dados is! List) {
        throw const FormatException('Resposta inválida dos comentários.');
      }

      for (final item in dados) {
        if (item is! Map) continue;

        final dataTexto = item['creationDateTime'] ?? item['datetime'];

        comentarios.add(
          DeckComentario(
            id: '${item['id'] ?? ''}',
            autor:
                '${item['actorDisplayName'] ?? item['actorId'] ?? 'Usuário'}',
            mensagem: '${item['message'] ?? ''}',
            data: dataTexto == null
                ? null
                : DateTime.tryParse('$dataTexto')?.toLocal(),
          ),
        );
      }

      if (dados.length < limite) break;
    }

    return comentarios;
  }

  Future<void> comentar({
    required ChamadoManutencao chamado,
    required String mensagem,
  }) async {
    final texto = mensagem.trim();

    if (texto.isEmpty) {
      throw ArgumentError('Escreva um comentário.');
    }

    if (texto.length > 1000) {
      throw ArgumentError('O comentário deve ter no máximo 1000 caracteres.');
    }

    final config = await _config();

    await _json(
      config,
      'POST',
      'ocs/v2.php/apps/deck/api/v1.0/'
          'cards/${chamado.id}/comments',
      dados: {'message': texto, 'parentId': null},
    );
  }

  // ============================================================
  // ANEXOS
  // ============================================================

  Future<List<DeckAnexo>> listarAnexos(ChamadoManutencao chamado) async {
    final config = await _config();

    final dados = await _json(
      config,
      'GET',
      '${_caminhoCartao(chamado)}/attachments',
    );

    if (dados is! List) {
      throw const FormatException('Resposta inválida dos anexos.');
    }

    return dados
        .whereType<Map>()
        .map((item) {
          final valor = item['data'];

          final nome = valor is Map
              ? (valor['name'] ?? valor['filename'] ?? valor['fileName'] ?? '')
              : valor;

          return DeckAnexo(
            id: _inteiro(item['id']) ?? 0,
            nome: '$nome',
            tipo: '${item['type'] ?? ''}',
          );
        })
        .where((item) => item.id > 0)
        .toList();
  }

  Future<void> anexarFoto({
    required ChamadoManutencao chamado,
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('A fotografia está vazia.');
    }

    final config = await _config();

    final caminho = '${_caminhoCartao(chamado)}/attachments';

    final request = http.MultipartRequest('POST', _url(config, caminho));

    request.followRedirects = false;
    request.headers.addAll(_headers(config));

    request.fields['type'] = 'file';

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: nomeArquivo),
    );

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 90));

    final response = await http.Response.fromStream(streamed);

    _verificarResposta(response, caminho);
  }

  // ============================================================
  // FINALIZAÇÃO E MOVIMENTAÇÃO
  // ============================================================

  Future<void> concluir(ChamadoManutencao chamado) async {
    final config = await _config();
    final boardId = chamado.boardId;
    final cardId = chamado.id;

    final listas = await _buscarListas(config, boardId);

    int? origemId;
    int? destinoId;
    Map<String, dynamic>? cartaoAtual;

    for (final lista in listas) {
      if (lista is! Map) continue;
      if (_excluido(lista['deletedAt'])) continue;

      final listaId = _inteiro(lista['id']);
      if (listaId == null) continue;

      if (_listaConcluida('${lista['title'] ?? ''}')) {
        destinoId = listaId;
      }

      final cartoes = lista['cards'];
      if (cartoes is! List) continue;

      for (final card in cartoes) {
        if (card is! Map) continue;
        if (_inteiro(card['id']) != cardId) continue;

        if (card['archived'] == true || _excluido(card['deletedAt'])) {
          throw StateError('O cartão $cardId está arquivado ou excluído.');
        }

        origemId = listaId;
        cartaoAtual = Map<String, dynamic>.from(card);
      }
    }

    if (origemId == null || cartaoAtual == null) {
      throw StateError('Cartão $cardId não encontrado.');
    }

    if (destinoId == null) {
      throw StateError('Coluna Concluído não encontrada.');
    }

    // 1. Movimentação já validada no servidor.
    if (origemId != destinoId) {
      await _json(
        config,
        'PUT',
        'index.php/apps/deck/api/v1.0/'
            'boards/$boardId/stacks/$destinoId/'
            'cards/$cardId/reorder',
        dados: {'stackId': destinoId, 'order': 999},
      );
    }

    // 2. Busca o cartão novamente após a movimentação.
    final listasAtualizadas = await _buscarListas(config, boardId);

    Map<String, dynamic>? cartaoAtualizado;
    int? stackAtual;

    for (final lista in listasAtualizadas) {
      if (lista is! Map) continue;

      final listaId = _inteiro(lista['id']);
      final cartoes = lista['cards'];

      if (cartoes is! List) continue;

      for (final card in cartoes) {
        if (card is! Map) continue;
        if (_inteiro(card['id']) != cardId) continue;

        stackAtual = listaId;
        cartaoAtualizado = Map<String, dynamic>.from(card);
        break;
      }
    }

    if (stackAtual != destinoId || cartaoAtualizado == null) {
      throw StateError('O cartão $cardId não foi movimentado corretamente.');
    }

    // 3. Marca como concluído preservando os dados.
    if (!_temConclusao(cartaoAtualizado['done'])) {
      final owner = cartaoAtualizado['owner'];

      String ownerId;

      if (owner is Map) {
        ownerId = '${owner['primaryKey'] ?? owner['uid'] ?? ''}';
      } else {
        ownerId = '$owner';
      }

      if (ownerId.isEmpty || ownerId == 'null') {
        throw StateError(
          'Não foi possível identificar o proprietário '
          'do cartão $cardId.',
        );
      }

      final dataConclusao = DateTime.now().toUtc().toIso8601String();

      await _json(
        config,
        'PUT',
        'index.php/apps/deck/api/v1.0/'
            'boards/$boardId/stacks/$destinoId/cards/$cardId',
        dados: {
          'title': cartaoAtualizado['title'],
          'description': cartaoAtualizado['description'] ?? '',
          'type': cartaoAtualizado['type'] ?? 'plain',
          'owner': ownerId,
          'order': cartaoAtualizado['order'] ?? 999,
          'duedate': cartaoAtualizado['duedate'],
          'archived': false,
          'done': dataConclusao,
        },
      );
    }

    // 4. Confirma a conclusão no servidor.
    final verificacao = await _buscarListas(config, boardId);

    for (final lista in verificacao) {
      if (lista is! Map) continue;

      final listaId = _inteiro(lista['id']);
      final cartoes = lista['cards'];

      if (cartoes is! List) continue;

      for (final card in cartoes) {
        if (card is! Map) continue;
        if (_inteiro(card['id']) != cardId) continue;

        if (listaId != destinoId) {
          throw StateError('O cartão não está na coluna Concluído.');
        }

        if (!_temConclusao(card['done'])) {
          throw StateError(
            'O Nextcloud não confirmou '
            'a marcação como concluído.',
          );
        }

        return;
      }
    }

    throw StateError(
      'Não foi possível verificar o cartão $cardId '
      'após a conclusão.',
    );
  }

  // ============================================================
  // ENCERRAMENTO
  // ============================================================

  void dispose() {
    _client.close();
  }
}
