import 'package:flutter/material.dart';

import '../../../colors/colors.dart';
import '../services/manutencao_prioridade.dart';
import '../services/app_manutencao_acesso_service.dart';
import '../services/manutencao_deck_gerencial_service.dart';

class SolicitarManutencaoPage extends StatefulWidget {
  const SolicitarManutencaoPage({super.key});

  @override
  State<SolicitarManutencaoPage> createState() =>
      _SolicitarManutencaoPageState();
}

class _SolicitarManutencaoPageState extends State<SolicitarManutencaoPage> {
  final _form = GlobalKey<FormState>();

  final _equipamento = TextEditingController();
  final _descricao = TextEditingController();
  final _tecnico = TextEditingController();

  final _service = ManutencaoDeckGerencialService();

  late Future<List<DeckOpcao>> _etiquetasFuture;

  int? _listaId;
  int? _etiquetaId;

  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _etiquetasFuture = _carregar();
  }

  Future<List<DeckOpcao>> _carregar() async {
    final acesso = await AppManutencaoAcessoService().carregar();

    if (!acesso.solicitar) {
      throw StateError('Você não possui permissão para solicitar manutenção.');
    }

    final listas = await _service.listas();

    // Localizar automaticamente a coluna de destino.
    final triagem = listas.where(
      (lista) => lista.nome.trim().toLowerCase() == 'aguardando triagem',
    );

    if (triagem.isEmpty) {
      throw StateError(
        'A coluna "Aguardando Triagem" não foi encontrada '
        'no quadro de manutenção do Nextcloud Deck.',
      );
    }

    _listaId = triagem.first.id;

    // Carregar as etiquetas reais do Nextcloud Deck.
    return _service.etiquetas();
  }

  @override
  void dispose() {
    _equipamento.dispose();
    _descricao.dispose();
    _tecnico.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_enviando) return;

    if (!_form.currentState!.validate()) {
      return;
    }

    if (_listaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A coluna Aguardando Triagem não está disponível.'),
        ),
      );
      return;
    }

    if (_etiquetaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma etiqueta de prioridade.')),
      );
      return;
    }

    setState(() {
      _enviando = true;
    });

    try {
      // A prioridade é atribuída diretamente como etiqueta
      // ao cartão do Nextcloud Deck.
      //
      // A descrição contém somente as observações
      // e a sugestão de técnico.

      final detalhes = <String>[
        _descricao.text.trim(),
        if (_tecnico.text.trim().isNotEmpty)
          'Técnico sugerido: ${_tecnico.text.trim()}',
      ].where((e) => e.isNotEmpty).join('\n\n');

      await _service.criar(
        titulo: _equipamento.text.trim(),
        descricao: detalhes,
        stackId: _listaId!,
        prioridadeId: _etiquetaId!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitação enviada para Aguardando Triagem '
            'com a prioridade selecionada.',
          ),
          backgroundColor: BillhardColors.verdePrincipal,
        ),
      );

      _form.currentState!.reset();

      _equipamento.clear();
      _descricao.clear();
      _tecnico.clear();

      setState(() {
        _etiquetaId = null;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao enviar solicitação: $e'),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  Widget _tituloCampo(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: BillhardColors.verdePrincipal,
      ),
    );
  }

  InputDecoration _decoracao({required String hint, required IconData icone}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icone, color: BillhardColors.verdePrincipal),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: BillhardColors.verdeSecundario),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: BillhardColors.verdeSecundario),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: BillhardColors.verdePrincipal,
          width: 2,
        ),
      ),
    );
  }

  Widget _opcaoPrioridade(DeckOpcao etiqueta) {
    final selecionada = _etiquetaId == etiqueta.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: _enviando
            ? null
            : () {
                setState(() {
                  _etiquetaId = etiqueta.id;
                });
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selecionada
                ? BillhardColors.verdeSecundario.withValues(alpha: 0.35)
                : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selecionada
                  ? BillhardColors.verdePrincipal
                  : BillhardColors.verdeSecundario,
              width: selecionada ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selecionada
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: BillhardColors.verdePrincipal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  etiqueta.nome,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: BillhardColors.verdePrincipal,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ManutencaoPrioridade.cor(etiqueta.cor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulario(List<DeckOpcao> etiquetas) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Abrir solicitação',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: BillhardColors.verdePrincipal,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Registre uma nova solicitação de manutenção.',
            style: TextStyle(color: BillhardColors.verdePrincipal),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // EQUIPAMENTO
                _tituloCampo('Nome do equipamento ou ambiente *'),
                const SizedBox(height: 9),

                TextFormField(
                  controller: _equipamento,
                  enabled: !_enviando,
                  decoration: _decoracao(
                    hint: 'Ex.: Forno, Compressor, Sala de Produção...',
                    icone: Icons.build_outlined,
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Informe o equipamento ou ambiente';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // PRIORIDADE
                _tituloCampo('Nível de prioridade *'),
                const SizedBox(height: 9),

                if (etiquetas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Nenhuma etiqueta disponível no quadro.'),
                  ),

                for (final etiqueta in etiquetas) _opcaoPrioridade(etiqueta),

                const SizedBox(height: 20),

                // DESTINO AUTOMÁTICO
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BillhardColors.verdeSecundario.withValues(
                      alpha: 0.25,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: BillhardColors.verdePrincipal,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Destino automático: Aguardando Triagem',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: BillhardColors.verdePrincipal,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.check_circle_outline,
                        color: BillhardColors.verdePrincipal,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // TÉCNICO SUGERIDO
                _tituloCampo('Sugestão de técnico'),
                const SizedBox(height: 9),

                TextFormField(
                  controller: _tecnico,
                  enabled: !_enviando,
                  decoration: _decoracao(
                    hint: 'Nome do técnico (opcional)',
                    icone: Icons.engineering_outlined,
                  ),
                ),

                const SizedBox(height: 24),

                // DESCRIÇÃO
                _tituloCampo('Descrição / Observações'),
                const SizedBox(height: 9),

                TextFormField(
                  controller: _descricao,
                  enabled: !_enviando,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: _decoracao(
                    hint:
                        'Descreva o problema, sintomas ou detalhes adicionais...',
                    icone: Icons.description_outlined,
                  ),
                ),

                const SizedBox(height: 18),

                // ENVIAR
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _enviando ? null : _salvar,
                    style: FilledButton.styleFrom(
                      backgroundColor: BillhardColors.verdePrincipal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _enviando
                          ? 'Enviando solicitação...'
                          : 'Enviar solicitação',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BillhardColors.bege,
      appBar: AppBar(
        title: const Text(
          'Manutenção',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: BillhardColors.verdePrincipal,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<DeckOpcao>>(
        future: _etiquetasFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: BillhardColors.verdePrincipal,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _etiquetasFuture = _carregar();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: BillhardColors.verdePrincipal,
              ),
            );
          }

          return _formulario(snapshot.data!);
        },
      ),
    );
  }
}
