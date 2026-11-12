import 'package:flutter/material.dart';
import '../../../colors/colors.dart';
import '../services/app_manutencao_acesso_service.dart';
import '../services/manutencao_deck_gerencial_service.dart';
import '../services/manutencao_prioridade.dart';

class ChamadosPage extends StatefulWidget {
  const ChamadosPage({super.key});
  @override
  State<ChamadosPage> createState() => _ChamadosPageState();
}

class _ChamadosPageState extends State<ChamadosPage> {
  final service = ManutencaoDeckGerencialService();
  final busca = TextEditingController();
  late Future<List<DeckChamadoGerencial>> futuro;
  String filtro = 'Todos';
  @override
  void initState() { super.initState(); futuro = _carregar(); }
  Future<List<DeckChamadoGerencial>> _carregar() async {
    if (!(await AppManutencaoAcessoService().carregar()).chamados) throw StateError('Acesso negado a Chamados.');
    return service.listar();
  }
  @override
  void dispose() { busca.dispose(); service.dispose(); super.dispose(); }
  void atualizar() => setState(() => futuro = _carregar());
  String situacao(DeckChamadoGerencial c) {
    if (c.concluido) return 'Concluída';
    if (c.vencimento == null) return 'Sem data';
    final hoje = DateTime.now();
    final dias = DateTime(c.vencimento!.year,c.vencimento!.month,c.vencimento!.day)
      .difference(DateTime(hoje.year,hoje.month,hoje.day)).inDays;
    if (dias < 0) return 'Atrasada';
    if (dias == 0) return 'Hoje';
    if (dias == 1) return 'Amanhã';
    return 'Próximos dias';
  }
  Color cor(String s) => switch(s) {
    'Atrasada' => Colors.red.shade700, 'Amanhã' => Colors.orange.shade800,
    'Próximos dias' => Colors.blue.shade700, _ => BillhardColors.verdePrincipal,
  };
  String data(DateTime? d) => d == null ? 'Sem vencimento' :
    '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BillhardColors.bege,
    appBar: AppBar(title: const Text('Chamados'), backgroundColor: BillhardColors.verdePrincipal,
      foregroundColor: Colors.white, actions: [IconButton(onPressed: atualizar, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<List<DeckChamadoGerencial>>(future: futuro, builder: (context,s) {
      if (!s.hasData) return Center(child: s.hasError ? Text('${s.error}') : const CircularProgressIndicator());
      final todos = s.data!;
      final itens = todos.where((c) => (filtro == 'Todos' || situacao(c) == filtro) &&
        '${c.titulo} ${c.tecnico} ${c.lista}'.toLowerCase().contains(busca.text.toLowerCase())).toList()
        ..sort((a,b) => (a.vencimento ?? DateTime(9999)).compareTo(b.vencimento ?? DateTime(9999)));
      return Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          TextField(controller: busca, onChanged: (_) => setState(() {}), decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search), hintText: 'Buscar chamado, equipamento ou técnico', filled: true, fillColor: Colors.white)),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final f in ['Todos','Atrasada','Hoje','Amanhã','Próximos dias','Sem data','Concluída'])
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(f),
                selected: filtro == f, onSelected: (_) => setState(() => filtro = f))),
          ])),
        ])),
        Expanded(child: RefreshIndicator(onRefresh: () async { atualizar(); await futuro; }, child: ListView.builder(
          itemCount: itens.length, itemBuilder: (context,i) {
            final c = itens[i], status = situacao(c);
            return Card(color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 16,vertical: 6),
              child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(c.titulo, style: const TextStyle(fontSize: 16,fontWeight: FontWeight.bold))),
                  Text(status, style: TextStyle(color: cor(status),fontWeight: FontWeight.bold))]),
                const SizedBox(height: 8),
                Text('Vencimento: ${data(c.vencimento)}'),
                Text('Técnico: ${c.tecnico}'),
                Text('Etapa: ${c.lista}'),
                if (c.etiquetas.isNotEmpty) Wrap(spacing: 5, children: [for (final e in c.etiquetas)
                  Chip(label: Text(e.nome), backgroundColor: ManutencaoPrioridade.cor(e.cor).withValues(alpha: .2))]),
              ])));
          },
        ))),
      ]);
    }),
  );
}
