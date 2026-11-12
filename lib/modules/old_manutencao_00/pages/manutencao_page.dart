import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:billhard_app_mobile/modules/conta/pages/conta.dart';
import '../../../colors/colors.dart';
import '../services/deck_service.dart';
import '../services/manutencao_permissao_service.dart';
import '../services/nextcloud_config_service.dart';
import '../services/manutencao_local_service.dart';
import '../services/manutencao_sync_service.dart';
import '../../../shared/utils/responsive.dart';
import 'package:billhard_app_mobile/shared/services/pagina_persistente_service.dart';

ThemeData _temaManutencao(BuildContext context) {
  final base = Theme.of(context);
  final esquema = ColorScheme.fromSeed(
    seedColor: BillhardColors.verdePrincipal,
    primary: BillhardColors.verdePrincipal,
    onPrimary: Colors.white,
    secondary: BillhardColors.verdeSecundario,
    onSecondary: BillhardColors.verdePrincipal,
    surface: Colors.white,
    onSurface: BillhardColors.verdePrincipal,
    error: NutribreadsColors.vermelhoMedio,
    onError: Colors.white,
  );
  return base.copyWith(
    colorScheme: esquema,
    scaffoldBackgroundColor: BillhardColors.bege,
    cardColor: Colors.white,
    iconTheme: const IconThemeData(color: BillhardColors.verdePrincipal),
    textTheme: base.textTheme.apply(
      bodyColor: BillhardColors.verdePrincipal,
      displayColor: BillhardColors.verdePrincipal,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BillhardColors.verdePrincipal,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BillhardColors.verdePrincipal,
        side: const BorderSide(color: BillhardColors.verdePrincipal),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BillhardColors.verdePrincipal,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BillhardColors.verdePrincipal,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: BillhardColors.verdePrincipal,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}

class _AvisoSincronizacao extends StatefulWidget {
  const _AvisoSincronizacao({required this.pendentes, required this.erro});
  final int pendentes;
  final String? erro;
  @override
  State<_AvisoSincronizacao> createState() => _AvisoSincronizacaoState();
}

class _AvisoSincronizacaoState extends State<_AvisoSincronizacao> {
  bool _expandido = false;
  @override
  Widget build(BuildContext context) {
    final erro = widget.erro?.trim() ?? '';
    final temErro = erro.isNotEmpty;
    final temPendencias = widget.pendentes > 0;
    if (!temErro && !temPendencias) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: temPendencias
            ? NutribreadsColors.vermelhoClaro
            : BillhardColors.bege,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: temPendencias
              ? NutribreadsColors.vermelhoMedio
              : BillhardColors.verdeSecundario,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                temPendencias
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
                color: temPendencias
                    ? NutribreadsColors.vermelhoEscuro
                    : BillhardColors.verdePrincipal,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  temPendencias
                      ? '${widget.pendentes} envio(s) '
                            'pendente(s). Clique em Sync.'
                      : 'Aviso da última sincronização',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: temPendencias
                        ? NutribreadsColors.vermelhoEscuro
                        : BillhardColors.verdePrincipal,
                  ),
                ),
              ),
              if (temErro)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _expandido = !_expandido;
                    });
                  },
                  child: Text(_expandido ? 'Ocultar' : 'Ver aviso'),
                ),
            ],
          ),
          if (_expandido && temErro) ...[
            const Divider(),
            SelectableText(erro),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: erro));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro copiado.')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar erro'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ManutencaoPage extends StatefulWidget {
  const ManutencaoPage({super.key});
  @override
  State<ManutencaoPage> createState() => _ManutencaoPageState();
}

class _ManutencaoPageState extends State<ManutencaoPage>
    with WidgetsBindingObserver {
  final _deck = DeckService();
  final _configuracoes = NextcloudConfigService();
  final _permissoes = ManutencaoPermissaoService();
  final _local = ManutencaoLocalService();

  late final _sync = ManutencaoSyncService(deck: _deck, local: _local);

  late Future<List<ChamadoManutencao>> _chamados;

  bool _sincronizando = false;
  String? _erroSync;
  int _pendentesSync = 0;

  Future<void> _salvarPaginaAtual() async {
    await PaginaPersistenteService.salvarPagina('ManutencaoPage');

    debugPrint('Página ManutencaoPage salva');
  }

  @override
  void initState() {
    super.initState();

    _salvarPaginaAtual();

    WidgetsBinding.instance.addObserver(this);

    _chamados = _buscar();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncInicial();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncInicial();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deck.dispose();
    super.dispose();
  }

  Future<List<ChamadoManutencao>> _buscar() async {
    await _permissoes.exigirPermissao();
    return _sync.agendaLocal();
  }

  Future<void> _syncInicial() async {
    if (_sincronizando) return;
    try {
      await _sync.sincronizarSeNecessario();
    } catch (e) {
      debugPrint('Sync inicial: $e');
    } finally {
      if (mounted) await _relerLocal();
    }
  }

  Future<void> _relerLocal() async {
    final consulta = _buscar();
    if (mounted) {
      setState(() {
        _chamados = consulta;
      });
    }
    try {
      await consulta;
      final quadro = await _sync.quadroAtual();
      if (quadro == null) return;
      final pendentes = await _local.operacoes(
        boardId: quadro,
        somentePendentes: true,
      );
      final aviso = await _local.avisoSync(quadro);
      if (!mounted) return;
      setState(() {
        _pendentesSync = pendentes.length;
        _erroSync = aviso;
      });
    } catch (e) {
      debugPrint('Cache manutenção: $e');
    }
  }

  void _mensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _atualizar() async {
    if (_sincronizando) return;
    setState(() {
      _sincronizando = true;
    });
    try {
      final resultado = await _sync.sincronizar();
      _mensagem(
        resultado.sucesso
            ? 'Sincronização concluída.'
            : 'Sincronização pendente. '
                  'Os registros locais foram preservados.',
      );
    } catch (e) {
      debugPrint('Erro Sync: $e');
      _mensagem('Não foi possível sincronizar agora.');
    } finally {
      if (mounted) {
        setState(() {
          _sincronizando = false;
        });
        await _relerLocal();
      }
    }
  }

  Future<void> _gerenciarPendencias() async {
    if (_sincronizando) return;
    final quadro = await _sync.quadroAtual();
    if (quadro == null || !mounted) return;

    final operacoes = await _local.operacoes(
      boardId: quadro,
      somentePendentes: true,
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Theme(
        data: _temaManutencao(dialogContext),
        child: AlertDialog(
          backgroundColor: BillhardColors.bege,
          title: Text(
            'Pendências de sincronização',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: BillhardColors.verdePrincipal,
            ),
          ),
          content: SizedBox(
            width: 460,
            child: operacoes.isEmpty
                ? const Text('Nenhuma operação pendente.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: operacoes.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final op = operacoes[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Cartão ${op.cardId} • ${op.tipo}'),
                        subtitle: Text(
                          op.tipo == 'comentario'
                              ? op.texto
                              : op.nomeArquivo.isNotEmpty
                              ? op.nomeArquivo
                              : 'Operação pendente de envio',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Remover pendência',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: NutribreadsColors.vermelhoEscuro,
                          ),
                          onPressed: () async {
                            final confirmar = await showDialog<bool>(
                              context: dialogContext,
                              builder: (confirmContext) => Theme(
                                data: _temaManutencao(confirmContext),
                                child: AlertDialog(
                                  backgroundColor: BillhardColors.bege,
                                  title: Text(
                                    'Remover pendência?',
                                    style: GoogleFonts.manrope(
                                      color: BillhardColors.verdePrincipal,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  content: Text(
                                    'Remover ${op.tipo} do cartão ${op.cardId} '
                                    'da fila local? A operação não será '
                                    'enviada ao Nextcloud.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(confirmContext, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(confirmContext, true),
                                      child: const Text('Remover'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (confirmar != true) return;
                            final box = await _local.box;
                            final chave = 'op:${op.id}';
                            final atual = box.get(chave);
                            if (atual == null) return;
                            // Não apaga arquivos de mídia ou histórico.
                            await box.delete(chave);
                            final restantes = await _local.operacoes(
                              boardId: quadro,
                              somentePendentes: true,
                            );
                            if (restantes.isEmpty) {
                              await _local.limparAvisoSync(quadro);
                            }
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (mounted) {
                              await _relerLocal();
                              _mensagem('Pendência removida da fila local.');
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirConfiguracoes() async {
    try {
      await _permissoes.exigirPermissao();
      final atual = await _configuracoes.carregar();
      if (!mounted) return;
      final alterou = await showDialog<bool>(
        context: context,
        builder: (_) => _ModalNextcloud(
          atual: atual,
          configuracoes: _configuracoes,
          deck: _deck,
        ),
      );
      if (alterou == true && mounted) {
        await _atualizar();
      }
    } catch (e) {
      debugPrint('Configuração Nextcloud: $e');
      _mensagem('Não foi possível abrir as configurações.');
    }
  }

  String _categoria(ChamadoManutencao c) {
    if (c.concluido) return 'Concluídas';
    if (c.garantia) return 'Manutenções em garantia';
    if (c.data == null) return 'Sem data';
    final hoje = DateTime.now();
    final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final data = DateTime(c.data!.year, c.data!.month, c.data!.day);
    final dias = data.difference(inicioHoje).inDays;
    if (dias < 0) return 'Atrasadas';
    if (dias == 0) return 'Hoje';
    if (dias == 1) return 'Amanhã';
    return 'Próximos dias';
  }

  String _data(DateTime? data) {
    if (data == null) return 'Sem agendamento';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(data.day)}/${dois(data.month)}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ui = BillhardResponsive(context);
    return Theme(
      data: _temaManutencao(context),
      child: Scaffold(
        backgroundColor: BillhardColors.bege,
        appBar: AppBar(
          backgroundColor: BillhardColors.verdePrincipal,
          foregroundColor: Colors.white,
          title: Text(
            'Manutenção',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (_sincronizando)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              IconButton(
                tooltip: 'Sair',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const Conta()),
                  );
                },
                icon: const Icon(Icons.logout_outlined),
              ),
            IconButton(
              tooltip: 'Configurar Nextcloud',
              onPressed: _abrirConfiguracoes,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ui.desktop ? 1100 : double.infinity,
              ),
              child: FutureBuilder<List<ChamadoManutencao>>(
                future: _chamados,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _erro(snapshot.error);
                  }
                  return _agenda(snapshot.data ?? [], ui);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _erro(Object? erro) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline,
              size: 48,
              color: BillhardColors.terraCota,
            ),
            const SizedBox(height: 16),
            Text(
              'Não foi possível carregar a agenda',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _relerLocal,
              child: const Text('Tentar novamente'),
            ),
            TextButton(
              onPressed: _abrirConfiguracoes,
              child: const Text('Configurar Nextcloud'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _agenda(List<ChamadoManutencao> chamados, BillhardResponsive ui) {
    const categorias = [
      'Manutenções em garantia',
      'Atrasadas',
      'Hoje',
      'Amanhã',
      'Próximos dias',
      'Sem data',
      'Concluídas',
    ];
    return RefreshIndicator(
      color: BillhardColors.verdePrincipal,
      onRefresh: _atualizar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(ui.mobile ? 16 : 24),
        children: [
          Text(
            'Minha agenda',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: BillhardColors.verdePrincipal,
              fontSize: Theme.of(context).textTheme.headlineSmall?.fontSize,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${chamados.where((c) => !c.concluido).length} '
            'manutenções pendentes',
          ),
          const SizedBox(height: 16),
          _AvisoSincronizacao(pendentes: _pendentesSync, erro: _erroSync),
          if (_pendentesSync > 0) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sincronizando ? null : _atualizar,
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar pendências'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sincronizando ? null : _gerenciarPendencias,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remover pendência'),
            ),
          ],
          const SizedBox(height: 20),
          if (chamados.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('Nenhuma manutenção atribuída a você.'),
              ),
            ),
          for (final categoria in categorias)
            if (chamados.any((c) => _categoria(c) == categoria)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  categoria,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: categoria == 'Manutenções em garantia'
                        ? NutribreadsColors.vermelhoEscuro
                        : BillhardColors.verdePrincipal,
                  ),
                ),
              ),
              for (final c in chamados.where((c) => _categoria(c) == categoria))
                _cartaoAgenda(c),
            ],
        ],
      ),
    );
  }

  Widget _cartaoAgenda(ChamadoManutencao chamado) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  _Detalhes(chamado: chamado, sync: _sync, local: _local),
            ),
          );
          if (mounted) await _relerLocal();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                chamado.garantia
                    ? Icons.build_circle
                    : chamado.concluido
                    ? Icons.check_circle
                    : Icons.build_circle_outlined,
                color: chamado.garantia
                    ? NutribreadsColors.vermelhoMedio
                    : BillhardColors.verdePrincipal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chamado.titulo,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        color: BillhardColors.verdePrincipal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_data(chamado.data)} • '
                      '${chamado.nomeLista}',
                    ),
                    if (chamado.garantia)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'REINCIDÊNCIA DE FALHA — GARANTIA',
                          style: TextStyle(
                            color: NutribreadsColors.vermelhoEscuro,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (chamado.etiquetas.isNotEmpty)
                      Text(chamado.etiquetas.join(' • ')),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: BillhardColors.verdePrincipal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalNextcloud extends StatefulWidget {
  const _ModalNextcloud({
    required this.atual,
    required this.configuracoes,
    required this.deck,
  });
  final NextcloudConfig? atual;
  final NextcloudConfigService configuracoes;
  final DeckService deck;
  @override
  State<_ModalNextcloud> createState() => _ModalNextcloudState();
}

class _ModalNextcloudState extends State<_ModalNextcloud> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _url;
  late final TextEditingController _usuario;
  late final TextEditingController _senha;
  List<DeckQuadro> _quadros = [];
  int? _quadroSelecionado;
  bool _carregando = false;
  bool _mostrarSenha = false;
  bool _quadrosCarregados = false;
  String? _erro;
  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.atual?.url ?? '');
    _usuario = TextEditingController(text: widget.atual?.usuario ?? '');
    _senha = TextEditingController(text: widget.atual?.senha ?? '');
    _quadroSelecionado = widget.atual?.quadroId;
    _url.addListener(_invalidar);
    _usuario.addListener(_invalidar);
    _senha.addListener(_invalidar);
  }

  void _invalidar() {
    if (!_quadrosCarregados) return;
    setState(() {
      _quadrosCarregados = false;
      _quadros = [];
      _quadroSelecionado = null;
    });
  }

  @override
  void dispose() {
    _url.removeListener(_invalidar);
    _usuario.removeListener(_invalidar);
    _senha.removeListener(_invalidar);
    _url.dispose();
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  NextcloudConfig _config({int? quadroId, String? quadroNome}) {
    return NextcloudConfig(
      url: _url.text.trim().replaceAll(RegExp(r'/$'), ''),
      usuario: _usuario.text.trim(),
      senha: _senha.text,
      quadroId: quadroId,
      quadroNome: quadroNome,
    );
  }

  String? _validarUrl(String? valor) {
    final uri = Uri.tryParse((valor ?? '').trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return 'Informe uma URL HTTPS válida.';
    }
    return null;
  }

  Future<void> _buscarQuadros() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final quadros = await widget.deck.listarQuadros(_config());
      if (!mounted) return;
      int? selecionado;
      final anterior = widget.atual?.quadroId;
      if (quadros.any((q) => q.id == anterior)) {
        selecionado = anterior;
      } else {
        for (final q in quadros) {
          if (q.nome.toLowerCase() == 'manutenção nutribreads') {
            selecionado = q.id;
            break;
          }
        }
      }
      setState(() {
        _quadros = quadros;
        _quadroSelecionado = selecionado;
        _quadrosCarregados = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = '$e');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_quadrosCarregados) {
      await _buscarQuadros();
      return;
    }
    if (_quadroSelecionado == null) {
      setState(() {
        _erro = 'Selecione um quadro.';
      });
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final quadro = _quadros.firstWhere((q) => q.id == _quadroSelecionado);
      await widget.configuracoes.salvar(
        _config(quadroId: quadro.id, quadroNome: quadro.nome),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = '$e');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _remover() async {
    setState(() {
      _carregando = true;
    });
    try {
      await widget.configuracoes.excluir();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = '$e');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _temaManutencao(context),
      child: AlertDialog(
        backgroundColor: BillhardColors.bege,
        title: Text(
          'Configurar Nextcloud',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: BillhardColors.verdePrincipal,
          ),
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _url,
                    enabled: !_carregando,
                    decoration: const InputDecoration(
                      labelText: 'https://exemplo.nextcloud.com',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validarUrl,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usuario,
                    enabled: !_carregando,
                    decoration: const InputDecoration(
                      labelText: 'Usuário',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Informe o usuário.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senha,
                    enabled: !_carregando,
                    obscureText: !_mostrarSenha,
                    decoration: InputDecoration(
                      labelText: 'Senha de aplicativo',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _mostrarSenha = !_mostrarSenha;
                          });
                        },
                        icon: Icon(
                          _mostrarSenha
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Informe a senha.' : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _carregando ? null : _buscarQuadros,
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text('Buscar quadros'),
                  ),
                  const SizedBox(height: 12),
                  if (_quadrosCarregados)
                    DropdownButtonFormField<int>(
                      key: ValueKey('${_quadros.length}-$_quadroSelecionado'),
                      initialValue: _quadroSelecionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Quadro',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final q in _quadros)
                          DropdownMenuItem(
                            value: q.id,
                            child: Text(
                              q.nome,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _carregando
                          ? null
                          : (valor) {
                              setState(() {
                                _quadroSelecionado = valor;
                              });
                            },
                    ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _erro!,
                      style: const TextStyle(
                        color: NutribreadsColors.vermelhoEscuro,
                      ),
                    ),
                  ],
                  if (_carregando) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (widget.atual != null)
            TextButton(
              onPressed: _carregando ? null : _remover,
              child: const Text('Remover conexão'),
            ),
          TextButton(
            onPressed: _carregando
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _carregando ? null : _salvar,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class _Detalhes extends StatefulWidget {
  const _Detalhes({
    required this.chamado,
    required this.sync,
    required this.local,
  });
  final ChamadoManutencao chamado;
  final ManutencaoSyncService sync;
  final ManutencaoLocalService local;
  @override
  State<_Detalhes> createState() => _DetalhesState();
}

class _DetalhesState extends State<_Detalhes> {
  final _texto = TextEditingController();
  final _camera = ImagePicker();
  List<DeckComentario> _comentarios = [];
  List<DeckAnexo> _anexos = [];
  List<OperacaoManutencao> _operacoes = [];
  bool _finalizada = false;
  bool _ocupado = false;
  String? _erroSync;
  @override
  void initState() {
    super.initState();
    _reler();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _aviso(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _reler() async {
    try {
      final comentarios = await widget.sync.comentarios(widget.chamado);
      final anexos = await widget.sync.anexos(widget.chamado);
      final operacoes = await widget.sync.operacoes(widget.chamado);
      final finalizada = await widget.sync.visitaFinalizada(widget.chamado);
      final aviso = await widget.local.avisoSync(widget.chamado.boardId);
      if (!mounted) return;
      setState(() {
        _comentarios = comentarios;
        _anexos = anexos;
        _operacoes = operacoes;
        _finalizada = finalizada;
        _erroSync = aviso;
      });
    } catch (e) {
      debugPrint('Detalhes locais: $e');
    }
  }

  Future<void> _comentar() async {
    if (_ocupado || _finalizada || _texto.text.trim().isEmpty) {
      return;
    }
    setState(() => _ocupado = true);
    try {
      await widget.sync.comentar(widget.chamado, _texto.text);
      _texto.clear();
      await _reler();
      _aviso('Comentário salvo no dispositivo.');
    } catch (e) {
      debugPrint('Comentário: $e');
      _aviso('Não foi possível salvar o comentário.');
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
      }
    }
  }

  Future<void> _capturar({required bool video}) async {
    if (_ocupado || _finalizada) return;
    try {
      final XFile? arquivo;
      if (video) {
        arquivo = await _camera.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        );
      } else {
        arquivo = await _camera.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
        );
      }
      if (arquivo == null || !mounted) return;
      setState(() => _ocupado = true);
      final extensao = arquivo.path.split('.').last.toLowerCase();
      await widget.sync.adicionarMidia(
        widget.chamado,
        caminhoTemporario: arquivo.path,
        extensao: video && !['mp4', 'mov'].contains(extensao)
            ? 'mov'
            : extensao,
      );
      await _reler();
      _aviso(video ? 'Vídeo salvo offline.' : 'Fotografia salva offline.');
    } catch (e) {
      debugPrint('Mídia: $e');
      _aviso('Não foi possível salvar a mídia.');
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
      }
    }
  }

  Future<void> _sincronizar() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final resultado = await widget.sync.sincronizar(chamado: widget.chamado);
      await _reler();
      _aviso(
        resultado.sucesso
            ? 'Sincronização concluída.'
            : 'Sincronização pendente. '
                  'Os dados foram preservados.',
      );
    } catch (e) {
      debugPrint('Sync cartão: $e');
      _aviso('Não foi possível sincronizar agora.');
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
      }
    }
  }

  Future<void> _finalizar() async {
    if (_ocupado || _finalizada) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: _temaManutencao(dialogContext),
        child: AlertDialog(
          backgroundColor: BillhardColors.bege,
          title: Text(
            'Finalizar visita?',
            style: GoogleFonts.manrope(
              color: BillhardColors.verdePrincipal,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'A conclusão será salva no dispositivo '
            'e enviada ao Nextcloud na sincronização.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await widget.sync.finalizarVisita(widget.chamado);
      await _reler();
      _aviso(
        'Visita finalizada localmente. '
        'A conclusão será sincronizada com o Deck.',
      );
    } catch (e) {
      debugPrint('Finalização: $e');
      _aviso('Não foi possível salvar a finalização.');
      return;
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
      }
    }
    await _sincronizar();
  }

  Widget _secao(String titulo, Widget conteudo) {
    return Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: BillhardColors.verdePrincipal,
              ),
            ),
            const SizedBox(height: 14),
            conteudo,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chamado = widget.chamado;
    final pendentes = _operacoes.where((op) => !op.enviada).toList();
    final midias = _operacoes.where(
      (op) => op.tipo == 'foto' || op.tipo == 'video',
    );
    return Theme(
      data: _temaManutencao(context),
      child: Scaffold(
        backgroundColor: BillhardColors.bege,
        appBar: AppBar(
          backgroundColor: BillhardColors.verdePrincipal,
          foregroundColor: Colors.white,
          title: const Text('Detalhes da manutenção'),
          actions: [
            IconButton(
              tooltip: 'Sync',
              onPressed: _ocupado ? null : _sincronizar,
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _secao(
                chamado.titulo,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      chamado.descricao.isEmpty
                          ? 'Sem descrição.'
                          : chamado.descricao,
                    ),
                    const SizedBox(height: 12),
                    Text('Coluna no Deck: ${chamado.nomeLista}'),
                    Text(
                      'Estado: ${chamado.concluido ? 'Concluído' : 'Pendente'}',
                    ),
                    if (chamado.garantia) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NutribreadsColors.vermelhoClaro,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.build_circle,
                              color: NutribreadsColors.vermelhoEscuro,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'MANUTENÇÃO EM GARANTIA\n'
                                'Equipamento voltou a apresentar problema.',
                                style: TextStyle(
                                  color: NutribreadsColors.vermelhoEscuro,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _secao(
                'Sincronização',
                Column(
                  children: [
                    _AvisoSincronizacao(
                      pendentes: pendentes.length,
                      erro: _erroSync,
                    ),
                    if (pendentes.isEmpty)
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: BillhardColors.verdePrincipal,
                          ),
                          SizedBox(width: 8),
                          Expanded(child: Text('Sem envios pendentes.')),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _ocupado ? null : _sincronizar,
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _secao(
                'Fotografias, vídeos e anexos',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_anexos.isEmpty && midias.isEmpty)
                      const Text('Nenhum anexo registrado.'),
                    for (final anexo in _anexos)
                      ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(anexo.nome),
                        subtitle: const Text('No Nextcloud'),
                      ),
                    for (final op in midias)
                      ListTile(
                        leading: Icon(
                          op.tipo == 'video'
                              ? Icons.videocam
                              : Icons.camera_alt,
                        ),
                        title: Text(
                          op.nomeArquivo,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          op.enviada ? 'Enviado' : 'Pendente de Sync',
                          style: TextStyle(
                            color: op.enviada
                                ? BillhardColors.verdePrincipal
                                : NutribreadsColors.vermelhoEscuro,
                            fontWeight: op.enviada
                                ? FontWeight.normal
                                : FontWeight.w800,
                          ),
                        ),
                        trailing:
                            op.tipo == 'foto' && File(op.arquivo).existsSync()
                            ? Image.file(
                                File(op.arquivo),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                    if (!_finalizada) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _ocupado
                            ? null
                            : () => _capturar(video: false),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tirar foto'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _ocupado
                            ? null
                            : () => _capturar(video: true),
                        icon: const Icon(Icons.videocam),
                        label: const Text('Gravar vídeo'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _secao(
                'Comentários',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_comentarios.isEmpty)
                      const Text('Nenhum comentário registrado.'),
                    for (final c in _comentarios)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          c.autor,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: SelectableText(c.mensagem),
                      ),
                    if (!_finalizada) ...[
                      TextField(
                        controller: _texto,
                        enabled: !_ocupado,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 900,
                        decoration: const InputDecoration(
                          labelText: 'Novo comentário',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _ocupado ? null : _comentar,
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar comentário'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _secao(
                'Visita técnica',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _finalizada
                          ? 'Visita finalizada neste dispositivo.'
                          : chamado.garantia
                          ? 'Nova visita em garantia.'
                          : 'Visita em andamento.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _ocupado || _finalizada ? null : _finalizar,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          _finalizada
                              ? 'Visita finalizada'
                              : 'Finalizar visita',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
