import 'dart:io';
import 'dart:math';

import 'deck_service.dart';
import 'manutencao_local_service.dart';
import 'nextcloud_config_service.dart';

class ResultadoSync {
  final int enviadas;
  final int pendentes;
  final String? erro;

  const ResultadoSync({
    required this.enviadas,
    required this.pendentes,
    this.erro,
  });

  bool get sucesso => erro == null && pendentes == 0;
}

class ManutencaoSyncService {
  ManutencaoSyncService({
    required DeckService deck,
    required ManutencaoLocalService local,
  }) : _deck = deck,
       _local = local;

  final DeckService _deck;
  final ManutencaoLocalService _local;
  final _config = NextcloudConfigService();

  Future<ResultadoSync>? _emCurso;

  String _id() {
    return '${DateTime.now().microsecondsSinceEpoch}_'
        '${Random.secure().nextInt(1 << 32)}';
  }

  String _data(DateTime valor) {
    final data = valor.toLocal();

    String dois(int n) => n.toString().padLeft(2, '0');

    return '${dois(data.day)}/${dois(data.month)}/'
        '${data.year} às '
        '${dois(data.hour)}:${dois(data.minute)}';
  }

  Future<int?> quadroAtual() async {
    return (await _config.carregar())?.quadroId;
  }

  Future<List<ChamadoManutencao>> agendaLocal() async {
    final id = await quadroAtual();

    return id == null ? [] : _local.chamados(id);
  }

  Future<void> comentar(ChamadoManutencao chamado, String texto) async {
    final mensagem = texto.trim();

    if (mensagem.isEmpty) {
      throw ArgumentError('Comentário vazio.');
    }

    if (mensagem.length > 900) {
      throw ArgumentError('Máximo de 900 caracteres.');
    }

    await _local.adicionarOperacao(
      OperacaoManutencao(
        id: _id(),
        boardId: chamado.boardId,
        cardId: chamado.id,
        tipo: 'comentario',
        texto: mensagem,
        arquivo: '',
        nomeArquivo: '',
        criadaEm: DateTime.now(),
      ),
    );
  }

  Future<void> adicionarMidia(
    ChamadoManutencao chamado, {
    required String caminhoTemporario,
    required String extensao,
  }) async {
    final ext = extensao.toLowerCase().replaceAll('.', '');

    if (!['jpg', 'jpeg', 'png', 'mp4', 'mov'].contains(ext)) {
      throw ArgumentError('Formato não permitido: $ext');
    }

    final id = _id();
    final nome = 'billhard_${chamado.id}_$id.$ext';

    final caminho = await _local.guardarMidia(caminhoTemporario, nome);

    try {
      await _local.adicionarOperacao(
        OperacaoManutencao(
          id: id,
          boardId: chamado.boardId,
          cardId: chamado.id,
          tipo: ['mp4', 'mov'].contains(ext) ? 'video' : 'foto',
          texto: '',
          arquivo: caminho,
          nomeArquivo: nome,
          criadaEm: DateTime.now(),
        ),
      );
    } catch (_) {
      await _local.excluirMidia(caminho);
      rethrow;
    }
  }

  Future<void> finalizarVisita(ChamadoManutencao chamado) async {
    if (await _local.visitaFinalizada(chamado.boardId, chamado.id)) {
      return;
    }

    final agora = DateTime.now();

    await _local.adicionarOperacao(
      OperacaoManutencao(
        id: _id(),
        boardId: chamado.boardId,
        cardId: chamado.id,
        tipo: 'finalizacao',
        texto: 'Visita finalizada em ${_data(agora)}.',
        arquivo: '',
        nomeArquivo: '',
        criadaEm: agora,
      ),
    );

    await _local.finalizarVisita(chamado.boardId, chamado.id, agora);
  }

  Future<List<OperacaoManutencao>> operacoes(ChamadoManutencao chamado) {
    return _local.operacoes(boardId: chamado.boardId, cardId: chamado.id);
  }

  Future<bool> visitaFinalizada(ChamadoManutencao chamado) {
    return _local.visitaFinalizada(chamado.boardId, chamado.id);
  }

  Future<List<DeckComentario>> comentarios(ChamadoManutencao chamado) async {
    final remotos = await _local.comentarios(chamado.boardId, chamado.id);

    final operacoes = await _local.operacoes(
      boardId: chamado.boardId,
      cardId: chamado.id,
      somentePendentes: true,
    );

    String limpar(String texto) {
      return texto.replaceAll(RegExp(r'\s*\[Billhard:[^\]\r\n]+\]'), '').trim();
    }

    return [
      for (final c in remotos)
        DeckComentario(
          id: c.id,
          autor: c.autor,
          mensagem: limpar(c.mensagem),
          data: c.data,
        ),
      for (final op in operacoes)
        if (op.tipo == 'comentario' || op.tipo == 'finalizacao')
          DeckComentario(
            id: op.id,
            autor: 'Pendente de Sync',
            mensagem: op.texto,
            data: op.criadaEm,
          ),
    ];
  }

  Future<List<DeckAnexo>> anexos(ChamadoManutencao chamado) {
    return _local.anexos(chamado.boardId, chamado.id);
  }

  Future<void> sincronizarSeNecessario() async {
    final id = await quadroAtual();
    if (id == null) return;

    final ultima = await _local.ultimaSincronizacao(id);

    final pendentes = await _local.operacoes(
      boardId: id,
      somentePendentes: true,
    );

    if (ultima == null ||
        DateTime.now().difference(ultima) >= const Duration(hours: 24) ||
        pendentes.isNotEmpty) {
      await sincronizar();
    }
  }

  Future<ResultadoSync> sincronizar({
    ChamadoManutencao? chamado,
    bool atualizarAgenda = true,
  }) {
    final existente = _emCurso;

    if (existente != null) return existente;

    final tarefa = _executar(
      chamado: chamado,
      atualizarAgenda: atualizarAgenda,
    );

    _emCurso = tarefa;

    return tarefa.whenComplete(() {
      _emCurso = null;
    });
  }

  Future<ResultadoSync> _executar({
    ChamadoManutencao? chamado,
    required bool atualizarAgenda,
  }) async {
    final boardId = chamado?.boardId ?? await quadroAtual();

    if (boardId == null) {
      return const ResultadoSync(
        enviadas: 0,
        pendentes: 0,
        erro: 'Configure um quadro Nextcloud.',
      );
    }

    var enviados = 0;
    String? erro;

    // Consulta os cartões ativos antes de enviar.
    // Isso evita enviar operações para cartões
    // arquivados ou excluídos.
    List<ChamadoManutencao>? remotos;

    try {
      remotos = await _deck.buscarMeusChamados();
    } catch (e) {
      erro = '$e';
    }

    if (remotos != null) {
      // A lista remota é a fonte de verdade.
      await _local.salvarChamados(boardId, remotos);

      await _local.registrarSincronizacao(boardId);
    }

    // Não envia nada sem conseguir confirmar
    // a situação atual do cartão no Deck.
    if (remotos != null) {
      final idsAtivos = remotos.map((c) => c.id).toSet();

      final pendentes = await _local.operacoes(
        boardId: boardId,
        cardId: chamado?.id,
        somentePendentes: true,
      );

      final grupos = <int, List<OperacaoManutencao>>{};

      for (final op in pendentes) {
        grupos.putIfAbsent(op.cardId, () => []).add(op);
      }

      for (final grupo in grupos.entries) {
        if (!idsAtivos.contains(grupo.key)) {
          // Cartão não está mais ativo/atribuído.
          // Mantém a fila para auditoria e não envia.
          continue;
        }

        ChamadoManutencao? cartao;

        for (final c in remotos) {
          if (c.id == grupo.key) {
            cartao = c;
            break;
          }
        }

        if (cartao == null) continue;

        final operacoes = grupo.value;

        operacoes.sort((a, b) {
          if (a.tipo == 'finalizacao' && b.tipo != 'finalizacao') {
            return 1;
          }

          if (b.tipo == 'finalizacao' && a.tipo != 'finalizacao') {
            return -1;
          }

          return a.criadaEm.compareTo(b.criadaEm);
        });

        for (final op in operacoes) {
          try {
            if (op.tipo == 'comentario') {
              await _enviarComentario(cartao, op);
            } else if (op.tipo == 'foto' || op.tipo == 'video') {
              await _enviarMidia(cartao, op);
            } else if (op.tipo == 'finalizacao') {
              await _enviarFinalizacao(cartao, op);
            } else {
              throw StateError('Operação desconhecida: ${op.tipo}');
            }

            await _local.marcarEnviada(op.id);
            enviados++;
          } catch (e) {
            erro ??= '$e';
            // Não continua com operações seguintes
            // do mesmo cartão após uma falha.
            break;
          }
        }
      }

      // Reconsulta o Deck depois dos envios.
      try {
        final atualizados = await _deck.buscarMeusChamados();

        await _local.salvarChamados(boardId, atualizados);

        remotos = atualizados;
      } catch (e) {
        erro ??= '$e';
      }
    }

    // Atualiza os comentários e anexos dos
    // cartões que permanecem ativos.
    if (remotos != null) {
      final cartoes = chamado == null
          ? remotos
          : remotos.where((c) => c.id == chamado.id).toList();

      for (final cartao in cartoes) {
        try {
          final comentarios = await _deck.listarComentarios(cartao);

          await _local.salvarComentarios(
            cartao.boardId,
            cartao.id,
            comentarios,
          );
        } catch (e) {
          // Um 403 em comentários não deve
          // impedir a leitura dos anexos.
          erro ??= '$e';
        }

        try {
          final anexos = await _deck.listarAnexos(cartao);

          await _local.salvarAnexos(cartao.boardId, cartao.id, anexos);
        } catch (e) {
          erro ??= '$e';
        }
      }
    }

    final restantes = await _local.operacoes(
      boardId: boardId,
      cardId: chamado?.id,
      somentePendentes: true,
    );

    if (erro != null) {
      await _local.salvarAvisoSync(boardId, erro);
    } else if (restantes.isEmpty) {
      await _local.limparAvisoSync(boardId);
    }

    return ResultadoSync(
      enviadas: enviados,
      pendentes: restantes.length,
      erro: erro,
    );
  }

  Future<void> _enviarComentario(
    ChamadoManutencao chamado,
    OperacaoManutencao op,
  ) async {
    final existentes = await _deck.listarComentarios(chamado);

    final marcadorAntigo = '[Billhard:${op.id}]';

    if (existentes.any((c) => c.mensagem.contains(marcadorAntigo))) {
      return;
    }

    await _deck.comentar(chamado: chamado, mensagem: op.texto);
  }

  Future<void> _enviarMidia(
    ChamadoManutencao chamado,
    OperacaoManutencao op,
  ) async {
    final existentes = await _deck.listarAnexos(chamado);

    if (existentes.any((a) => a.nome == op.nomeArquivo)) {
      return;
    }

    final arquivo = File(op.arquivo);

    if (!await arquivo.exists()) {
      throw StateError('Arquivo local ausente: ${op.nomeArquivo}');
    }

    await _deck.anexarFoto(
      chamado: chamado,
      bytes: await arquivo.readAsBytes(),
      nomeArquivo: op.nomeArquivo,
    );
  }

  Future<void> _enviarFinalizacao(
    ChamadoManutencao chamado,
    OperacaoManutencao op,
  ) async {
    final atual = await _deck.localizarCartao(chamado.boardId, chamado.id);

    if (atual == null) {
      throw StateError(
        'Cartão indisponível, arquivado ou excluído no Nextcloud.',
      );
    }

    // A conclusão do cartão não depende da permissão
    // de leitura dos comentários.
    await _deck.concluir(atual);
  }
}
