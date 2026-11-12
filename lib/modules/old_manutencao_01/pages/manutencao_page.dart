import 'package:flutter/material.dart';
import '../services/app_manutencao_acesso_service.dart';
import 'minha_agenda_original_page.dart';
import 'chamados_page.dart';
import 'solicitar_manutencao_page.dart';

/// Entrada estável do módulo; mantém as rotas existentes do aplicativo.
class ManutencaoPage extends StatefulWidget {
  const ManutencaoPage({super.key});
  @override
  State<ManutencaoPage> createState() => _ManutencaoPageState();
}

class _ManutencaoPageState extends State<ManutencaoPage> {
  late Future<AppManutencaoAcesso> _acesso;
  int _aba = 0;
  @override
  void initState() { super.initState(); _acesso = AppManutencaoAcessoService().carregar(); }
  @override
  Widget build(BuildContext context) => FutureBuilder<AppManutencaoAcesso>(
    future: _acesso,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Scaffold(appBar: AppBar(title: const Text('Manutenção')),
        body: Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(
          mainAxisSize: MainAxisSize.min, children: [Text('Não foi possível verificar as permissões: ${snapshot.error}', textAlign: TextAlign.center),
          const SizedBox(height: 12), ElevatedButton(onPressed: () => setState(() => _acesso = AppManutencaoAcessoService().carregar()), child: const Text('Tentar novamente'))]))));
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final a = snapshot.data!;
      final tabs = <({String titulo, IconData icone, Widget pagina})>[
        if (a.agenda) (titulo: 'Minha agenda', icone: Icons.event_note_outlined, pagina: const MinhaAgendaOriginalPage()),
        if (a.chamados) (titulo: 'Chamados', icone: Icons.assignment_outlined, pagina: const ChamadosPage()),
        if (a.solicitar) (titulo: 'Solicitar', icone: Icons.add_circle_outline, pagina: const SolicitarManutencaoPage()),
      ];
      if (tabs.isEmpty) return const Scaffold(body: Center(child: Text('Sem permissão para acessar as telas de manutenção.')));
      final indice = _aba.clamp(0, tabs.length - 1);
      return Scaffold(
        body: IndexedStack(index: indice, children: [for (final tab in tabs) tab.pagina]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: indice,
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: [for (final tab in tabs) NavigationDestination(icon: Icon(tab.icone), label: tab.titulo)],
        ),
      );
    },
  );
}
