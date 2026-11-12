import 'package:flutter/material.dart';
import '../../../colors/colors.dart';
import '../services/app_manutencao_acesso_service.dart';
import '../services/manutencao_deck_gerencial_service.dart';
import '../services/manutencao_prioridade.dart';
import 'chamado_detalhes_page.dart';

class ChamadosPage extends StatefulWidget {
  const ChamadosPage({super.key});
  @override
  State<ChamadosPage> createState() => _ChamadosPageState();
}

class _ChamadosPageState extends State<ChamadosPage> {
  final _service = ManutencaoDeckGerencialService();
  final _busca = TextEditingController();
  List<DeckChamadoGerencial> _cards = [];
  bool _carregando = true;
  bool _offline = false;
  bool _concluidas = false;
  String _filtro = 'Todos';
  String? _erro;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      if (!(await AppManutencaoAcessoService().carregar()).chamados) {
        throw StateError('Sem permissão para Chamados.');
      }
      final local = await _service.carregarCache();
      if (mounted) setState(() { _cards = local; _offline = true; });
      final remoto = await _service.listar();
      await _service.salvarCache(remoto);
      if (mounted) setState(() { _cards = remoto; _offline = false; });
    } catch (e) {
      if (mounted) setState(() { _erro = '$e'; _offline = true; });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() { _busca.dispose(); _service.dispose(); super.dispose(); }

  String _status(DeckChamadoGerencial c) {
    if (c.concluido) return 'Concluída';
    if (c.vencimento == null) return 'Sem data';
    final d = c.vencimento!;
    final h = DateTime.now();
    final dias = DateTime(d.year, d.month, d.day)
      .difference(DateTime(h.year, h.month, h.day)).inDays;
    if (dias < 0) return 'Atrasada';
    if (dias == 0) return 'Hoje';
    if (dias == 1) return 'Amanhã';
    return 'Próximos dias';
  }

  Color _cor(String s) => switch (s) {
    'Atrasada' => const Color(0xFFC62828),
    'Amanhã' => BillhardColors.terraCota,
    'Próximos dias' => const Color(0xFF1565C0),
    'Concluída' => const Color(0xFF15803D),
    _ => BillhardColors.verdePrincipal,
  };

  String _data(DateTime? d) => d == null ? 'Sem prazo' :
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _resumo(String nome, int total, Color cor, IconData icone) => Container(
    width: 122, margin: const EdgeInsets.only(right: 9), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border(bottom: BorderSide(color: cor, width: 4))),
    child: Column(children: [Icon(icone, color: cor, size: 27), const SizedBox(height: 6),
      Text('$total', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: BillhardColors.verdePrincipal)),
      Text(nome, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))]),
  );

  @override
  Widget build(BuildContext context) {
    final ativos = _cards.where((c) => !c.concluido).toList();
    final itens = _cards.where((c) => (_concluidas || !c.concluido) &&
      (_filtro == 'Todos' || _status(c) == _filtro) &&
      '${c.titulo} ${c.tecnico} ${c.lista} ${c.id}'.toLowerCase().contains(_busca.text.toLowerCase())).toList()
      ..sort((a, b) => (a.vencimento ?? DateTime(9999)).compareTo(b.vencimento ?? DateTime(9999)));
    return Scaffold(
      backgroundColor: BillhardColors.bege,
      appBar: AppBar(title: const Text('Manutenção', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: BillhardColors.verdePrincipal, foregroundColor: Colors.white,
        actions: [IconButton(tooltip: 'Atualizar', onPressed: _carregar, icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(onRefresh: _carregar, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24), children: [
        const Text('Chamados', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: BillhardColors.verdePrincipal)),
        const Text('Gerencie e acompanhe as manutenções da planta', style: TextStyle(color: BillhardColors.verdePrincipal)),
        if (_carregando) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(color: BillhardColors.verdePrincipal)),
        if (_offline) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Modo offline: exibindo última sincronização.',
          style: TextStyle(color: BillhardColors.terraCota))),
        if (_erro != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Falha na atualização: $_erro',
          style: const TextStyle(color: BillhardColors.terraCota))),
        const SizedBox(height: 20),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _resumo('Atrasadas', ativos.where((c) => _status(c) == 'Atrasada').length, _cor('Atrasada'), Icons.schedule),
          _resumo('Hoje', ativos.where((c) => _status(c) == 'Hoje').length, _cor('Hoje'), Icons.check_circle_outline),
          _resumo('Amanhã', ativos.where((c) => _status(c) == 'Amanhã').length, _cor('Amanhã'), Icons.event),
          _resumo('Próximos dias', ativos.where((c) => _status(c) == 'Próximos dias').length, _cor('Próximos dias'), Icons.date_range),
        ])),
        const SizedBox(height: 20),
        TextField(controller: _busca, onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Buscar chamado, equipamento ou técnico...',
            prefixIcon: Icon(Icons.search, color: BillhardColors.verdePrincipal))),
        SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar concluídas', style: TextStyle(color: BillhardColors.verdePrincipal, fontWeight: FontWeight.w700)),
          value: _concluidas, activeTrackColor: BillhardColors.verdeSecundario,
          onChanged: (v) => setState(() { _concluidas = v; if (!v && _filtro == 'Concluída') _filtro = 'Todos'; })),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final f in ['Todos', 'Atrasada', 'Hoje', 'Amanhã', 'Próximos dias', 'Sem data', if (_concluidas) 'Concluída'])
            Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(f),
              selected: _filtro == f, selectedColor: BillhardColors.verdeSecundario,
              labelStyle: const TextStyle(color: BillhardColors.verdePrincipal),
              onSelected: (_) => setState(() => _filtro = f))),
        ])),
        const SizedBox(height: 14),
        if (!_carregando && itens.isEmpty) const Padding(padding: EdgeInsets.all(28),
          child: Center(child: Text('Nenhum chamado encontrado.'))),
        for (final c in itens) _card(c),
      ])),
    );
  }

  Widget _card(DeckChamadoGerencial c) {
    final status = _status(c);
    final cor = _cor(status);
    return Container(margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17),
        border: Border(left: BorderSide(color: cor, width: 5))),
      child: InkWell(borderRadius: BorderRadius.circular(17),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChamadoDetalhesPage(chamado: c))),
        child: Padding(padding: const EdgeInsets.all(15), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(c.titulo, style: const TextStyle(fontSize: 16,
            fontWeight: FontWeight.w800, color: BillhardColors.verdePrincipal))),
            const Icon(Icons.chevron_right, color: BillhardColors.verdePrincipal)]),
          const SizedBox(height: 7),
          Text(c.lista, style: const TextStyle(color: BillhardColors.verdePrincipal)),
          const SizedBox(height: 7),
          Row(children: [Icon(Icons.person_outline, size: 17, color: BillhardColors.verdePrincipal),
            const SizedBox(width: 5), Expanded(child: Text(c.tecnico, maxLines: 1, overflow: TextOverflow.ellipsis))]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: cor.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
              child: Text(status, style: TextStyle(color: cor, fontWeight: FontWeight.bold))),
            Text('Venc.: ${_data(c.vencimento)}', style: TextStyle(color: cor)),
            for (final e in c.etiquetas) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: ManutencaoPrioridade.cor(e.cor).withValues(alpha: .18),
                borderRadius: BorderRadius.circular(14)), child: Text(e.nome, style: const TextStyle(fontSize: 12))),
          ]),
        ]))),
    );
  }
}
