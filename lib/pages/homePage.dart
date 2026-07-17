import 'package:flutter/material.dart';

import '../services/automotive_manager_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final AutomotiveManager _automotiveManager = AutomotiveManager.instance;

  late final TabController _tabController;

  final List<AutomotiveCardData> _equipamentos = const [
    AutomotiveCardData(
      id: 'casa-camara-01',
      titulo: 'Freezer Residencial',
      descricao: 'Temperatura: -18 °C',
      serialNumber: 'TK-R-0001',
      menu: AutomotiveMenu.residencial,
    ),
    AutomotiveCardData(
      id: 'casa-geladeira-02',
      titulo: 'Geladeira da Cozinha',
      descricao: 'Temperatura: 4 °C',
      serialNumber: 'TK-R-0002',
      menu: AutomotiveMenu.residencial,
    ),
    AutomotiveCardData(
      id: 'mercado-freezer-01',
      titulo: 'Freezer de Congelados',
      descricao: 'Temperatura: -20 °C',
      serialNumber: 'TK-C-0001',
      menu: AutomotiveMenu.comercial,
    ),
    AutomotiveCardData(
      id: 'mercado-camara-02',
      titulo: 'Câmara de Resfriamento',
      descricao: 'Temperatura: 2 °C',
      serialNumber: 'TK-C-0002',
      menu: AutomotiveMenu.comercial,
    ),
    AutomotiveCardData(
      id: 'industria-camara-01',
      titulo: 'Câmara de Matéria-Prima',
      descricao: 'Temperatura: 3 °C',
      serialNumber: 'TK-I-0001',
      menu: AutomotiveMenu.industrial,
    ),
    AutomotiveCardData(
      id: 'industria-tunel-02',
      titulo: 'Túnel de Congelamento',
      descricao: 'Temperatura: -30 °C',
      serialNumber: 'TK-I-0002',
      menu: AutomotiveMenu.industrial,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: AutomotiveMenu.values.length,
      vsync: this,
    );

    _automotiveManager.addListener(_onAutomotiveManagerChanged);
  }

  void _onAutomotiveManagerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  List<AutomotiveCardData> _equipamentosDoMenu(AutomotiveMenu menu) {
    return _equipamentos
        .where((equipamento) => equipamento.menu == menu)
        .toList();
  }

  Future<void> _alternarEquipamento(AutomotiveCardData equipamento) async {
    final estavaAdicionado = _automotiveManager.cardEstaAdicionado(
      id: equipamento.id,
      menu: equipamento.menu,
    );

    await _automotiveManager.alternarCard(equipamento);

    if (!mounted) {
      return;
    }

    final mensagem = estavaAdicionado
        ? '${equipamento.titulo} removido de '
              '${equipamento.menu.titulo}.'
        : '${equipamento.titulo} adicionado em '
              '${equipamento.menu.titulo}.';

    _mostrarMensagem(mensagem);
  }

  Future<void> _removerEquipamento(AutomotiveCardData equipamento) async {
    await _automotiveManager.removerCard(
      id: equipamento.id,
      menu: equipamento.menu,
    );

    if (!mounted) {
      return;
    }

    _mostrarMensagem('${equipamento.titulo} removido do veículo.');
  }

  Future<void> _removerMenu(AutomotiveMenu menu) async {
    final quantidade = _automotiveManager.quantidadeCardsNoMenu(menu);

    if (quantidade == 0) {
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Limpar ${menu.titulo}'),
          content: Text(
            'Deseja remover todos os equipamentos '
            'do menu ${menu.titulo}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    await _automotiveManager.removerCardsDoMenu(menu);

    if (!mounted) {
      return;
    }

    _mostrarMensagem('Menu ${menu.titulo} esvaziado.');
  }

  Future<void> _removerTodosOsCards() async {
    if (!_automotiveManager.possuiCards) {
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remover todos os cards'),
          content: const Text(
            'Deseja remover todos os equipamentos '
            'do CarPlay e Android Auto?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Remover todos'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    await _automotiveManager.removerTodosOsCards();

    if (!mounted) {
      return;
    }

    _mostrarMensagem('Todos os cards foram removidos.');
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  void dispose() {
    _automotiveManager.removeListener(_onAutomotiveManagerChanged);

    _tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ultimoClique = _automotiveManager.ultimoClique;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BillHard'),
        actions: [
          if (_automotiveManager.possuiCards)
            IconButton(
              tooltip: 'Remover todos',
              onPressed: _removerTodosOsCards,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home_outlined), text: 'Residencial'),
            Tab(icon: Icon(Icons.storefront_outlined), text: 'Comercial'),
            Tab(icon: Icon(Icons.factory_outlined), text: 'Industrial'),
          ],
        ),
      ),
      body: Column(
        children: [
          _cabecalhoConexao(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: AutomotiveMenu.values
                  .map((menu) => _paginaDoMenu(menu))
                  .toList(),
            ),
          ),
          if (ultimoClique != null) _cardUltimoClique(ultimoClique),
        ],
      ),
    );
  }

  Widget _cabecalhoConexao() {
    final conectado = _automotiveManager.conectado;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: conectado ? Colors.green.shade50 : Colors.grey.shade100,
      child: Row(
        children: [
          Icon(
            Icons.directions_car,
            color: conectado ? Colors.green.shade700 : Colors.grey.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _automotiveManager.plataforma,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _automotiveManager.statusConexao,
                  style: TextStyle(
                    fontSize: 13,
                    color: conectado
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: conectado ? Colors.green.shade100 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_automotiveManager.quantidadeTotalCards} cards',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginaDoMenu(AutomotiveMenu menu) {
    final equipamentosDisponiveis = _equipamentosDoMenu(menu);

    final cardsAdicionados = _automotiveManager.cardsDoMenu(menu);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Equipamentos ${menu.titulo}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (cardsAdicionados.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  _removerMenu(menu);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Limpar'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Selecione quais equipamentos serão '
          'exibidos na aba ${menu.titulo} do veículo.',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),

        ...equipamentosDisponiveis.map(_cardEquipamentoDisponivel),

        const SizedBox(height: 28),

        Row(
          children: [
            const Expanded(
              child: Text(
                'Exibidos no veículo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            CircleAvatar(
              radius: 15,
              child: Text(
                '${cardsAdicionados.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (cardsAdicionados.isEmpty)
          _listaVazia(menu)
        else
          ...cardsAdicionados.map(_cardEquipamentoAdicionado),
      ],
    );
  }

  Widget _cardEquipamentoDisponivel(AutomotiveCardData equipamento) {
    final adicionado = _automotiveManager.cardEstaAdicionado(
      id: equipamento.id,
      menu: equipamento.menu,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _alternarEquipamento(equipamento);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              CircleAvatar(child: Icon(_iconeDoMenu(equipamento.menu))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipamento.titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(equipamento.descricao),
                    if (equipamento.serialNumber != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        equipamento.serialNumber!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: adicionado,
                onChanged: (_) {
                  _alternarEquipamento(equipamento);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardEquipamentoAdicionado(AutomotiveCardData equipamento) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconeDoMenu(equipamento.menu))),
        title: Text(equipamento.titulo),
        subtitle: Text(equipamento.descricao),
        trailing: IconButton(
          tooltip: 'Remover do veículo',
          onPressed: () {
            _removerEquipamento(equipamento);
          },
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      ),
    );
  }

  Widget _listaVazia(AutomotiveMenu menu) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(_iconeDoMenu(menu), size: 46, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'Nenhum equipamento em '
            '${menu.titulo}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ative um equipamento acima para '
            'exibi-lo no veículo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _cardUltimoClique(AutomotiveCardClickEvent evento) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: ListTile(
            leading: const Icon(Icons.touch_app),
            title: Text(
              evento.card.titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${evento.card.menu.titulo} • '
              '${evento.plataforma} • '
              '${_formatarData(evento.dataHora)}',
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconeDoMenu(AutomotiveMenu menu) {
    switch (menu) {
      case AutomotiveMenu.residencial:
        return Icons.home_outlined;

      case AutomotiveMenu.comercial:
        return Icons.storefront_outlined;

      case AutomotiveMenu.industrial:
        return Icons.factory_outlined;
    }
  }

  String _formatarData(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');

    final minuto = data.minute.toString().padLeft(2, '0');

    final segundo = data.second.toString().padLeft(2, '0');

    return '$hora:$minuto:$segundo';
  }
}
