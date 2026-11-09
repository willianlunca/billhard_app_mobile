import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_carplay/flutter_carplay.dart';

/// Menu no qual o equipamento será exibido.
enum AutomotiveMenu { residencial, comercial, industrial }

extension AutomotiveMenuExtension on AutomotiveMenu {
  String get titulo {
    switch (this) {
      case AutomotiveMenu.residencial:
        return 'Residencial';

      case AutomotiveMenu.comercial:
        return 'Comercial';

      case AutomotiveMenu.industrial:
        return 'Industrial';
    }
  }

  /// Ícones do sistema utilizados nas abas.
  ///
  /// O CarPlay usa SF Symbols.
  /// O pacote também encaminha essa propriedade ao Android Auto.
  String get systemIcon {
    switch (this) {
      case AutomotiveMenu.residencial:
        return 'house.fill';

      case AutomotiveMenu.comercial:
        return 'building.2.fill';

      case AutomotiveMenu.industrial:
        return 'gearshape.2.fill';
    }
  }
}

class AutomotiveCardData {
  const AutomotiveCardData({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.menu,
    this.serialNumber,
  });

  final String id;
  final String titulo;
  final String descricao;
  final AutomotiveMenu menu;
  final String? serialNumber;

  AutomotiveCardData copyWith({
    String? id,
    String? titulo,
    String? descricao,
    AutomotiveMenu? menu,
    String? serialNumber,
  }) {
    return AutomotiveCardData(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      menu: menu ?? this.menu,
      serialNumber: serialNumber ?? this.serialNumber,
    );
  }
}

class AutomotiveCardClickEvent {
  const AutomotiveCardClickEvent({
    required this.card,
    required this.dataHora,
    required this.plataforma,
  });

  final AutomotiveCardData card;
  final DateTime dataHora;
  final String plataforma;
}

typedef AutomotiveCardPressedCallback =
    void Function(AutomotiveCardClickEvent event);

class AutomotiveManager extends ChangeNotifier {
  AutomotiveManager._();

  static final AutomotiveManager instance = AutomotiveManager._();

  final FlutterCarplay _flutterCarplay = FlutterCarplay();
  final FlutterAndroidAuto _flutterAndroidAuto = FlutterAndroidAuto();

  /// Os cards são separados por menu.
  final Map<AutomotiveMenu, Map<String, AutomotiveCardData>> _cardsPorMenu = {
    AutomotiveMenu.residencial: <String, AutomotiveCardData>{},
    AutomotiveMenu.comercial: <String, AutomotiveCardData>{},
    AutomotiveMenu.industrial: <String, AutomotiveCardData>{},
  };

  bool _inicializado = false;
  bool _templateConfigurado = false;

  String _statusConexao = 'Aguardando conexão com o veículo';

  ConnectionStatusTypes _connectionStatus = ConnectionStatusTypes.unknown;

  AutomotiveCardClickEvent? _ultimoClique;

  AutomotiveCardPressedCallback? onCardPressed;

  String get statusConexao => _statusConexao;

  ConnectionStatusTypes get connectionStatus => _connectionStatus;

  AutomotiveCardClickEvent? get ultimoClique => _ultimoClique;

  bool get conectado {
    return _connectionStatus == ConnectionStatusTypes.connected;
  }

  String get plataforma {
    if (Platform.isIOS) {
      return 'CarPlay';
    }

    if (Platform.isAndroid) {
      return 'Android Auto';
    }

    return 'Sistema automotivo';
  }

  int get quantidadeTotalCards {
    return _cardsPorMenu.values.fold(0, (total, cards) => total + cards.length);
  }

  bool get possuiCards => quantidadeTotalCards > 0;

  Future<void> inicializar({
    AutomotiveCardPressedCallback? onCardPressed,
  }) async {
    this.onCardPressed = onCardPressed;

    if (_inicializado) {
      return;
    }

    _inicializado = true;

    if (Platform.isIOS) {
      _flutterCarplay.addListenerOnConnectionChange(_onCarPlayConnectionChange);
    } else if (Platform.isAndroid) {
      _flutterAndroidAuto.addListenerOnConnectionChange(
        _onAndroidAutoConnectionChange,
      );
    }
  }

  // ============================================================
  // CONSULTAS
  // ============================================================

  List<AutomotiveCardData> cardsDoMenu(AutomotiveMenu menu) {
    final cards = _cardsPorMenu[menu];

    if (cards == null) {
      return const [];
    }

    return List<AutomotiveCardData>.unmodifiable(cards.values);
  }

  List<AutomotiveCardData> get todosOsCards {
    return List<AutomotiveCardData>.unmodifiable(
      AutomotiveMenu.values.expand(cardsDoMenu),
    );
  }

  int quantidadeCardsNoMenu(AutomotiveMenu menu) {
    return _cardsPorMenu[menu]?.length ?? 0;
  }

  bool cardEstaAdicionado({required String id, required AutomotiveMenu menu}) {
    return _cardsPorMenu[menu]?.containsKey(id) ?? false;
  }

  AutomotiveCardData? encontrarCard({
    required String id,
    required AutomotiveMenu menu,
  }) {
    return _cardsPorMenu[menu]?[id];
  }

  // ============================================================
  // ADICIONAR CARDS
  // ============================================================

  /// Adiciona um equipamento a um menu específico.
  ///
  /// Caso já exista um card com o mesmo ID no mesmo menu,
  /// os dados serão substituídos.
  Future<void> adicionarCard({
    required String id,
    required String titulo,
    required String descricao,
    required AutomotiveMenu menu,
    String? serialNumber,
  }) async {
    final card = AutomotiveCardData(
      id: id,
      titulo: titulo,
      descricao: descricao,
      menu: menu,
      serialNumber: serialNumber,
    );

    await adicionarCardSelecionado(card);
  }

  Future<void> adicionarCardSelecionado(AutomotiveCardData card) async {
    _cardsPorMenu[card.menu]![card.id] = card;

    notifyListeners();

    await _atualizarTemplate();
  }

  // ============================================================
  // REMOVER CARDS
  // ============================================================

  /// Remove um card de um menu específico.
  Future<void> removerCard({
    required String id,
    required AutomotiveMenu menu,
  }) async {
    final removido = _cardsPorMenu[menu]?.remove(id);

    if (removido == null) {
      debugPrint('Card não encontrado: $id em ${menu.titulo}.');

      return;
    }

    notifyListeners();

    await _atualizarTemplate();
  }

  /// Remove o card de qualquer menu em que ele esteja.
  Future<void> removerCardDeTodosOsMenus(String id) async {
    bool algumCardRemovido = false;

    for (final menu in AutomotiveMenu.values) {
      final removido = _cardsPorMenu[menu]?.remove(id);

      if (removido != null) {
        algumCardRemovido = true;
      }
    }

    if (!algumCardRemovido) {
      return;
    }

    notifyListeners();

    await _atualizarTemplate();
  }

  /// Remove todos os cards de um menu.
  Future<void> removerCardsDoMenu(AutomotiveMenu menu) async {
    final cards = _cardsPorMenu[menu];

    if (cards == null || cards.isEmpty) {
      return;
    }

    cards.clear();

    notifyListeners();

    await _atualizarTemplate();
  }

  /// Remove todos os cards de todos os menus.
  Future<void> removerTodosOsCards() async {
    for (final cards in _cardsPorMenu.values) {
      cards.clear();
    }

    notifyListeners();

    await _atualizarTemplate();
  }

  // ============================================================
  // ALTERNAR CARD
  // ============================================================

  /// Adiciona o card caso ele não esteja no menu.
  ///
  /// Remove caso já esteja no menu.
  Future<void> alternarCard(AutomotiveCardData card) async {
    final estaAdicionado = cardEstaAdicionado(id: card.id, menu: card.menu);

    if (estaAdicionado) {
      await removerCard(id: card.id, menu: card.menu);
    } else {
      await adicionarCardSelecionado(card);
    }
  }

  // ============================================================
  // MOVER ENTRE MENUS
  // ============================================================

  /// Move um card de um menu para outro.
  Future<void> moverCard({
    required String id,
    required AutomotiveMenu menuAtual,
    required AutomotiveMenu novoMenu,
  }) async {
    if (menuAtual == novoMenu) {
      return;
    }

    final card = _cardsPorMenu[menuAtual]?.remove(id);

    if (card == null) {
      debugPrint('Card não encontrado para movimentação: $id.');

      return;
    }

    final cardMovido = card.copyWith(menu: novoMenu);

    _cardsPorMenu[novoMenu]![id] = cardMovido;

    notifyListeners();

    await _atualizarTemplate();
  }

  // ============================================================
  // ATUALIZAR CARD
  // ============================================================

  /// Atualiza um equipamento dentro de determinado menu.
  ///
  /// Use esta função quando chegar uma atualização via MQTT
  /// ou HTTP.
  Future<void> atualizarCard({
    required String id,
    required AutomotiveMenu menu,
    String? titulo,
    String? descricao,
    String? serialNumber,
  }) async {
    final cardAtual = _cardsPorMenu[menu]?[id];

    if (cardAtual == null) {
      return;
    }

    final cardAtualizado = cardAtual.copyWith(
      titulo: titulo,
      descricao: descricao,
      serialNumber: serialNumber,
    );

    final naoMudou =
        cardAtualizado.titulo == cardAtual.titulo &&
        cardAtualizado.descricao == cardAtual.descricao &&
        cardAtualizado.serialNumber == cardAtual.serialNumber;

    if (naoMudou) {
      return;
    }

    _cardsPorMenu[menu]![id] = cardAtualizado;

    notifyListeners();

    await _atualizarTemplate();
  }

  /// Atualiza um card procurando-o em todos os menus.
  ///
  /// Essa função é útil quando o MQTT informa apenas o serial.
  Future<void> atualizarCardEmQualquerMenu({
    required String id,
    String? titulo,
    String? descricao,
    String? serialNumber,
  }) async {
    bool algumCardAtualizado = false;

    for (final menu in AutomotiveMenu.values) {
      final cardAtual = _cardsPorMenu[menu]?[id];

      if (cardAtual == null) {
        continue;
      }

      final cardAtualizado = cardAtual.copyWith(
        titulo: titulo,
        descricao: descricao,
        serialNumber: serialNumber,
      );

      final naoMudou =
          cardAtualizado.titulo == cardAtual.titulo &&
          cardAtualizado.descricao == cardAtual.descricao &&
          cardAtualizado.serialNumber == cardAtual.serialNumber;

      if (naoMudou) {
        continue;
      }

      _cardsPorMenu[menu]![id] = cardAtualizado;
      algumCardAtualizado = true;
    }

    if (!algumCardAtualizado) {
      return;
    }

    notifyListeners();

    await _atualizarTemplate();
  }

  // ============================================================
  // ATUALIZAÇÃO DO VEÍCULO
  // ============================================================

  Future<void> _atualizarTemplate() async {
    if (!conectado && _templateConfigurado) {
      debugPrint('Veículo desconectado. Dados mantidos em memória.');

      return;
    }

    try {
      if (Platform.isIOS) {
        await _configurarCarPlay();
      } else if (Platform.isAndroid) {
        await _configurarAndroidAuto();
      }
    } catch (erro, stackTrace) {
      debugPrint('Erro ao atualizar sistema automotivo: $erro');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ============================================================
  // CARPLAY
  // ============================================================

  Future<void> _configurarCarPlay() async {
    final tabs = AutomotiveMenu.values.map((menu) {
      return CPListTemplate(
        title: menu.titulo,
        tabTitle: menu.titulo,
        systemIcon: menu.systemIcon,
        sections: [
          CPListSection(header: menu.titulo, items: _criarItensCarPlay(menu)),
        ],
      );
    }).toList();

    final tabBarTemplate = CPTabBarTemplate(templates: tabs);

    await FlutterCarplay.setRootTemplate(
      rootTemplate: tabBarTemplate,
      animated: true,
    );

    _flutterCarplay.forceUpdateRootTemplate();

    _templateConfigurado = true;

    debugPrint(
      'CarPlay atualizado com '
      '$quantidadeTotalCards cards.',
    );
  }

  List<CPListItem> _criarItensCarPlay(AutomotiveMenu menu) {
    final cards = cardsDoMenu(menu);

    if (cards.isEmpty) {
      return [
        CPListItem(
          text: 'Nenhum equipamento',
          detailText: 'Adicione pelo aplicativo BillHard',
          onPress: (complete, self) {
            complete();
          },
        ),
      ];
    }

    return cards.map((card) {
      return CPListItem(
        text: card.titulo,
        detailText: card.descricao,
        onPress: (complete, self) {
          try {
            _registrarClique(card: card, plataforma: 'CarPlay');

            self.setDetailText('Selecionado');

            Future<void>.delayed(const Duration(milliseconds: 700), () {
              self.setDetailText(card.descricao);
              complete();
            });
          } catch (erro) {
            debugPrint(
              'Erro ao processar clique no CarPlay: '
              '$erro',
            );

            complete();
          }
        },
      );
    }).toList();
  }

  void _onCarPlayConnectionChange(ConnectionStatusTypes status) {
    _connectionStatus = status;

    switch (status) {
      case ConnectionStatusTypes.connected:
        _statusConexao = 'CarPlay conectado';
        break;

      case ConnectionStatusTypes.background:
        _statusConexao = 'CarPlay em segundo plano';
        break;

      case ConnectionStatusTypes.disconnected:
        _statusConexao = 'CarPlay desconectado';
        break;

      case ConnectionStatusTypes.unknown:
        _statusConexao = 'Estado do CarPlay desconhecido';
        break;
    }

    notifyListeners();

    if (status == ConnectionStatusTypes.connected) {
      _configurarCarPlay();
    }
  }

  // ============================================================
  // ANDROID AUTO
  // ============================================================

  Future<void> _configurarAndroidAuto() async {
    final tabs = AutomotiveMenu.values.map((menu) {
      return AAListTemplate(
        title: menu.titulo,
        tabTitle: menu.titulo,
        systemIcon: menu.systemIcon,
        sections: [
          AAListSection(
            title: menu.titulo,
            items: _criarItensAndroidAuto(menu),
          ),
        ],
        emptyViewTitleVariants: ['Nenhum equipamento em ${menu.titulo}'],
      );
    }).toList();

    final tabBarTemplate = AATabBarTemplate(tabs: tabs);

    await FlutterAndroidAuto.setRootTemplate(template: tabBarTemplate);

    _flutterAndroidAuto.forceUpdateRootTemplate();

    _templateConfigurado = true;

    debugPrint(
      'Android Auto atualizado com '
      '$quantidadeTotalCards cards.',
    );
  }

  List<AAListItem> _criarItensAndroidAuto(AutomotiveMenu menu) {
    final cards = cardsDoMenu(menu);

    if (cards.isEmpty) {
      return [
        AAListItem(
          title: 'Nenhum equipamento',
          subtitle: 'Adicione pelo aplicativo BillHard',
          onPress: (complete, self) {
            complete();
          },
        ),
      ];
    }

    return cards.map((card) {
      return AAListItem(
        title: card.titulo,
        subtitle: card.descricao,
        onPress: (complete, self) {
          try {
            _registrarClique(card: card, plataforma: 'Android Auto');
          } catch (erro) {
            debugPrint(
              'Erro ao processar clique no '
              'Android Auto: $erro',
            );
          } finally {
            complete();
          }
        },
      );
    }).toList();
  }

  void _onAndroidAutoConnectionChange(ConnectionStatusTypes status) {
    _connectionStatus = status;

    switch (status) {
      case ConnectionStatusTypes.connected:
        _statusConexao = 'Android Auto conectado';
        break;

      case ConnectionStatusTypes.background:
        _statusConexao = 'Android Auto em segundo plano';
        break;

      case ConnectionStatusTypes.disconnected:
        _statusConexao = 'Android Auto desconectado';
        break;

      case ConnectionStatusTypes.unknown:
        _statusConexao = 'Estado do Android Auto desconhecido';
        break;
    }

    notifyListeners();

    if (status == ConnectionStatusTypes.connected) {
      _configurarAndroidAuto();
    }
  }

  // ============================================================
  // CLIQUE
  // ============================================================

  void _registrarClique({
    required AutomotiveCardData card,
    required String plataforma,
  }) {
    final evento = AutomotiveCardClickEvent(
      card: card,
      dataHora: DateTime.now(),
      plataforma: plataforma,
    );

    _ultimoClique = evento;

    notifyListeners();

    onCardPressed?.call(evento);

    debugPrint(
      'Card clicado: ${card.titulo} | '
      '${card.menu.titulo} | $plataforma',
    );
  }

  // ============================================================
  // ENCERRAMENTO
  // ============================================================

  void encerrar() {
    if (!_inicializado) {
      return;
    }

    if (Platform.isIOS) {
      _flutterCarplay.removeListenerOnConnectionChange();
    }

    if (Platform.isAndroid) {
      _flutterAndroidAuto.removeListenerOnConnectionChange();
    }

    _inicializado = false;
    _templateConfigurado = false;
  }
}
