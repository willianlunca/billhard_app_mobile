import 'package:flutter/material.dart';
import '../services/app_manutencao_acesso_service.dart';
import '../services/manutencao_deck_gerencial_service.dart';

class SolicitarManutencaoPage extends StatefulWidget {
  const SolicitarManutencaoPage({super.key});
  @override
  State<SolicitarManutencaoPage> createState() => _SolicitarManutencaoPageState();
}

class _SolicitarManutencaoPageState extends State<SolicitarManutencaoPage> {
  final _form = GlobalKey<FormState>();
  final _equipamento = TextEditingController();
  final _descricao = TextEditingController();
  final _tecnico = TextEditingController();
  final _service = ManutencaoDeckGerencialService();
  late Future<({List<DeckOpcao> listas, List<DeckOpcao> etiquetas})> _dados;
  int? _listaId, _etiquetaId;
  bool _enviando = false;
  @override
  void initState() {
    super.initState();
    _dados = _carregar();
  }
  Future<({List<DeckOpcao> listas, List<DeckOpcao> etiquetas})> _carregar() async {
    final acesso = await AppManutencaoAcessoService().carregar();
    if (!acesso.solicitar) throw StateError('Sem permissão para solicitar manutenção.');
    final listas = await _service.listas();
    final etiquetas = await _service.etiquetas();
    return (listas: listas, etiquetas: etiquetas);
  }
  @override
  void dispose() { _equipamento.dispose(); _descricao.dispose(); _tecnico.dispose(); _service.dispose(); super.dispose(); }
  Future<void> _salvar() async {
    if (!_form.currentState!.validate() || _listaId == null) return;
    setState(() => _enviando = true);
    try {
      final dados = await _dados;
      final prioridade = dados.etiquetas.where((e) => e.id == _etiquetaId).toList();
      final detalhes = <String>[
        _descricao.text.trim(),
        if (_tecnico.text.trim().isNotEmpty) 'Técnico sugerido: ${_tecnico.text.trim()}',
        if (prioridade.isNotEmpty) 'Prioridade solicitada: ${prioridade.first.nome}',
      ].where((e) => e.isNotEmpty).join('\n\n');
      await _service.criar(titulo: _equipamento.text.trim(), descricao: detalhes,
        stackId: _listaId!, prioridadeId: _etiquetaId ?? 0);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitação criada no Deck. A prioridade e o técnico foram registrados na descrição, ainda não atribuídos ao cartão.')));
      _form.currentState!.reset(); _equipamento.clear(); _descricao.clear(); _tecnico.clear();
      setState(() => _etiquetaId = null);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao criar solicitação: $e')));
    } finally { if (mounted) setState(() => _enviando = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Abrir solicitação')),
    body: FutureBuilder<({List<DeckOpcao> listas, List<DeckOpcao> etiquetas})>(
      future: _dados, builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('${snapshot.error}')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final dados = snapshot.data!;
        return Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(controller: _equipamento, decoration: const InputDecoration(labelText: 'Equipamento ou ambiente', border: OutlineInputBorder()),
            validator: (v) => v == null || v.trim().isEmpty ? 'Informe o equipamento ou ambiente' : null),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(initialValue: _listaId, isExpanded: true, decoration: const InputDecoration(labelText: 'Lista de destino no Deck', border: OutlineInputBorder()),
            items: [for (final l in dados.listas) DropdownMenuItem(value: l.id, child: Text(l.nome))],
            onChanged: (v) => setState(() => _listaId = v), validator: (v) => v == null ? 'Selecione uma lista' : null),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(initialValue: _etiquetaId, isExpanded: true, decoration: const InputDecoration(labelText: 'Prioridade (etiqueta do Deck)', border: OutlineInputBorder()),
            items: [for (final l in dados.etiquetas) DropdownMenuItem(value: l.id, child: Text(l.nome))],
            onChanged: (v) => setState(() => _etiquetaId = v)),
          const SizedBox(height: 16),
          TextFormField(controller: _tecnico, decoration: const InputDecoration(labelText: 'Sugestão de técnico', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextFormField(controller: _descricao, maxLines: 5, decoration: const InputDecoration(labelText: 'Descrição do problema', border: OutlineInputBorder())),
          const SizedBox(height: 22),
          FilledButton.icon(onPressed: _enviando ? null : _salvar, icon: const Icon(Icons.send_outlined),
            label: Text(_enviando ? 'Enviando...' : 'Abrir chamado')),
        ]));
      },
    ),
  );
}
