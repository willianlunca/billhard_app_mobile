import 'package:flutter/material.dart';

import '../../../colors/colors.dart';
import '../services/app_manutencao_acesso_service.dart';
import 'minha_agenda_original_page.dart';
import 'chamados_page.dart';
import 'solicitar_manutencao_page.dart';

class ManutencaoPage extends StatefulWidget {
  const ManutencaoPage({super.key});

  @override
  State<ManutencaoPage> createState() => _ManutencaoPageState();
}

class _ManutencaoPageState extends State<ManutencaoPage> {
  final AppManutencaoAcessoService _acessoService =
      AppManutencaoAcessoService();

  late Future<AppManutencaoAcesso> _acesso;
  int _aba = 0;
  bool _verificando = false;

  @override
  void initState() {
    super.initState();
    _recarregar();
  }

  void _recarregar() {
    _acesso = _acessoService.carregar();
  }

  bool _permitido(AppManutencaoAcesso acesso, int indice) {
    switch (indice) {
      case 0:
        return acesso.agenda;
      case 1:
        return acesso.chamados;
      case 2:
        return acesso.solicitar;
      default:
        return false;
    }
  }

  int _primeiraAbaPermitida(AppManutencaoAcesso acesso) {
    for (var i = 0; i < 3; i++) {
      if (_permitido(acesso, i)) return i;
    }
    return -1;
  }

  Future<void> _selecionarAba(int indice) async {
    if (_verificando) return;
    setState(() => _verificando = true);

    try {
      // Consulta novamente a tabela app_manutencao em cada clique.
      final acessoAtual = await _acessoService.carregar();
      if (!mounted) return;

      if (!_permitido(acessoAtual, indice)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Você não possui permissão para acessar esta tela.',
              ),
              backgroundColor: BillhardColors.verdePrincipal,
            ),
          );
        return;
      }

      setState(() {
        _acesso = Future.value(acessoAtual);
        _aba = indice;
      });
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Não foi possível verificar sua permissão: $erro'),
            backgroundColor: BillhardColors.verdePrincipal,
          ),
        );
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: BillhardColors.verdePrincipal,
        primary: BillhardColors.verdePrincipal,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: BillhardColors.bege,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BillhardColors.verdeSecundario),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: BillhardColors.verdePrincipal,
            width: 2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BillhardColors.verdePrincipal,
          foregroundColor: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BillhardColors.verdePrincipal,
          foregroundColor: Colors.white,
        ),
      ),
    ),
    child: FutureBuilder<AppManutencaoAcesso>(
      future: _acesso,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Manutenção'),
              backgroundColor: BillhardColors.verdePrincipal,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 48,
                            color: BillhardColors.verdePrincipal,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Não foi possível verificar as permissões: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(_recarregar),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        }

        final acesso = snapshot.data!;
        final primeiraPermitida = _primeiraAbaPermitida(acesso);
        final indice = _permitido(acesso, _aba) ? _aba : primeiraPermitida;
        final abasPermitidas = <int>[
          for (var i = 0; i < 3; i++)
            if (_permitido(acesso, i)) i,
        ];

        const titulos = ['Minha agenda', 'Chamados', 'Solicitar'];
        const icones = [
          Icons.event_note_outlined,
          Icons.handyman_outlined,
          Icons.add_circle_outline,
        ];

        // Só instancia páginas autorizadas; as demais não são
        // montadas, nem carregam dados ou executam seus initState.
        final paginas = <Widget>[
          if (acesso.agenda)
            const MinhaAgendaOriginalPage()
          else
            const SizedBox.shrink(),
          if (acesso.chamados)
            const ChamadosPage()
          else
            const SizedBox.shrink(),
          if (acesso.solicitar)
            const SolicitarManutencaoPage()
          else
            const SizedBox.shrink(),
        ];

        return Scaffold(
          body: indice < 0
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Você não possui permissão para acessar sua própria agenda.',
                      style: TextStyle(
                        color: BillhardColors.terraCota,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : IndexedStack(index: indice, children: paginas),
          bottomNavigationBar: abasPermitidas.length <= 1
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    color: BillhardColors.verdePrincipal,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                      child: Row(
                        children: [
                          for (final i in abasPermitidas)
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _verificando
                                    ? null
                                    : () => _selecionarAba(i),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == indice
                                        ? Colors.white.withValues(alpha: .16)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icones[i],
                                        color: Colors.white,
                                        size: 27,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        titulos[i],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: i == indice
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    ),
  );
}
