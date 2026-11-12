import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../colors/colors.dart';
import '../services/manutencao_deck_gerencial_service.dart';
import '../services/manutencao_prioridade.dart';

class ChamadoDetalhesPage extends StatefulWidget {
  final DeckChamadoGerencial chamado;
  const ChamadoDetalhesPage({super.key, required this.chamado});
  @override
  State<ChamadoDetalhesPage> createState() => _ChamadoDetalhesPageState();
}

class _ChamadoDetalhesPageState extends State<ChamadoDetalhesPage> {
  final _service = ManutencaoDeckGerencialService();
  List<Map<String, dynamic>> _comentarios = [];
  bool _carregando = true;
  bool _offline = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _atualizar();
  }

  Future<void> _atualizar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      final local = await _service.carregarComentariosCache(widget.chamado.id);
      if (mounted) setState(() { _comentarios = local; _offline = true; });
      final remoto = await _service.comentarios(widget.chamado.id);
      await _service.salvarComentariosCache(widget.chamado.id, remoto);
      if (mounted) setState(() { _comentarios = remoto; _offline = false; });
    } catch (e) {
      if (mounted) setState(() { _erro = '$e'; _offline = true; });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() { _service.dispose(); super.dispose(); }

  String _data(dynamic value) {
    if (value == null) return 'Não informada';
    final d = value is DateTime ? value : DateTime.tryParse('$value');
    if (d == null) return '$value';
    final x = d.toLocal();
    return '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year} ${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  }

  Widget _secao(String titulo, Widget child) => Container(
    width: double.infinity, margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: BillhardColors.verdePrincipal)),
      const SizedBox(height: 12), child,
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.chamado;
    return Scaffold(
      backgroundColor: BillhardColors.bege,
      appBar: AppBar(title: const Text('Detalhes do chamado'),
        backgroundColor: BillhardColors.verdePrincipal, foregroundColor: Colors.white,
        actions: [IconButton(onPressed: _atualizar, icon: const Icon(Icons.refresh), tooltip: 'Atualizar comentários')]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_offline) const Padding(padding: EdgeInsets.only(bottom: 12),
          child: Text('Exibindo dados locais; comentários podem estar desatualizados.',
            style: TextStyle(color: BillhardColors.terraCota))),
        _secao('Chamado #${c.id}', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.titulo, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: BillhardColors.verdePrincipal)),
          const SizedBox(height: 12),
          Text('Coluna: ${c.lista}'), Text('Responsável: ${c.tecnico}'),
          Text('Vencimento: ${_data(c.vencimento)}'),
          Text('Situação: ${c.concluido ? 'Concluída' : 'Em andamento'}'),
          const SizedBox(height: 9),
          Wrap(spacing: 7, runSpacing: 6, children: [for (final e in c.etiquetas)
            Chip(label: Text(e.nome), backgroundColor: ManutencaoPrioridade.cor(e.cor).withValues(alpha: .18))]),
        ])),
        _secao('Descrição', c.descricao.trim().isEmpty
          ? const Text('Nenhuma descrição informada.')
          : _MarkdownSimples(texto: c.descricao)),
        _secao('Comentários', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_carregando) const LinearProgressIndicator(color: BillhardColors.verdePrincipal),
          if (_erro != null) Text('Não foi possível atualizar: $_erro', style: const TextStyle(color: BillhardColors.terraCota)),
          if (!_carregando && _comentarios.isEmpty) const Text('Nenhum comentário armazenado.'),
          for (final item in _comentarios) Padding(padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['actorDisplayName'] ?? item['actorId'] ?? 'Usuário'} · ${_data(item['creationDateTime'] ?? item['datetime'])}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: BillhardColors.verdePrincipal)),
              const SizedBox(height: 5),
              _MarkdownSimples(texto: '${item['message'] ?? ''}'),
              const Divider(),
            ])),
        ])),
      ]),
    );
  }
}

// Renderização leve de Markdown: títulos, listas, citações, código, links,
// negrito e itálico. Não executa HTML nem scripts de conteúdo externo.
class _MarkdownSimples extends StatelessWidget {
  final String texto;
  const _MarkdownSimples({required this.texto});

  List<InlineSpan> _spans(String linha) {
    final pattern = RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)|\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`|\*(.+?)\*|_(.+?)_');
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in pattern.allMatches(linha)) {
      if (m.start > pos) spans.add(TextSpan(text: linha.substring(pos, m.start)));
      if (m.group(1) != null) {
        final url = m.group(2)!;
        spans.add(WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic,
          child: InkWell(onTap: () async { final uri = Uri.tryParse(url); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); },
            child: Text(m.group(1)!, style: const TextStyle(color: BillhardColors.verdePrincipal, decoration: TextDecoration.underline)))));
      } else if (m.group(3) != null || m.group(4) != null) {
        spans.add(TextSpan(text: m.group(3) ?? m.group(4), style: const TextStyle(fontWeight: FontWeight.bold)));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(text: m.group(5), style: const TextStyle(fontFamily: 'monospace', backgroundColor: Color(0xFFE2DECC))));
      } else {
        spans.add(TextSpan(text: m.group(6) ?? m.group(7), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      pos = m.end;
    }
    if (pos < linha.length) spans.add(TextSpan(text: linha.substring(pos)));
    return spans;
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    for (final line in texto.split('\n')) Padding(padding: const EdgeInsets.only(bottom: 5), child:
      line.trim().isEmpty ? const SizedBox(height: 7) :
      Builder(builder: (context) {
        final trimmed = line.trimLeft();
        final header = RegExp(r'^#{1,6}\s+').firstMatch(trimmed);
        final bullet = RegExp(r'^(?:[-*+] |\d+\. )').firstMatch(trimmed);
        final quote = trimmed.startsWith('> ');
        final code = trimmed.startsWith('    ') || trimmed.startsWith('```');
        final content = header != null ? trimmed.substring(header.end) :
          bullet != null ? trimmed.substring(bullet.end) : quote ? trimmed.substring(2) : trimmed;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (bullet != null) const Padding(padding: EdgeInsets.only(right: 8), child: Text('•')),
          Expanded(child: RichText(text: TextSpan(style: TextStyle(
            color: BillhardColors.verdePrincipal, height: 1.4,
            fontSize: header != null ? 19 : 14,
            fontWeight: header != null ? FontWeight.bold : FontWeight.normal,
            fontFamily: code ? 'monospace' : null,
            fontStyle: quote ? FontStyle.italic : FontStyle.normal,
          ), children: _spans(content)))),
        ]);
      })),
  ]);
}
