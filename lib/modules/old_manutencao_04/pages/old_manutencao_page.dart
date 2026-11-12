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
  late Future<AppManutencaoAcesso> _acesso;
  int _aba = 0;
  @override
  void initState() {
    super.initState();
    _recarregar();
  }

  void _recarregar() {
    _acesso = AppManutencaoAcessoService().carregar();
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
        final abas = <({String titulo, IconData icone, Widget pagina})>[
          if (acesso.agenda)
            (
              titulo: 'Minha agenda',
              icone: Icons.event_note_outlined,
              pagina: const MinhaAgendaOriginalPage(),
            ),
          if (acesso.chamados)
            (
              titulo: 'Chamados',
              icone: Icons.handyman_outlined,
              pagina: const ChamadosPage(),
            ),
          if (acesso.solicitar)
            (
              titulo: 'Solicitar',
              icone: Icons.add_circle_outline,
              pagina: const SolicitarManutencaoPage(),
            ),
        ];
        if (abas.isEmpty)
          return const Scaffold(
            body: Center(
              child: Text('Sem permissão para acessar a manutenção.'),
            ),
          );
        final indice = _aba.clamp(0, abas.length - 1);
        return Scaffold(
          body: IndexedStack(
            index: indice,
            children: [for (final aba in abas) aba.pagina],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: BillhardColors.verdePrincipal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                child: Row(
                  children: [
                    for (var i = 0; i < abas.length; i++)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _aba = i),
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
                                  abas[i].icone,
                                  color: Colors.white,
                                  size: 27,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  abas[i].titulo,
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
