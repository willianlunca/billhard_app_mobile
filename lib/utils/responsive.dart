import 'package:flutter/material.dart';

class BillhardResponsive {
  final BuildContext context;

  BillhardResponsive(this.context);

  bool get mobile => largura < 600;
  bool get tablet => largura >= 600 && largura < 1200;
  bool get desktop => largura >= 1200;

  double get largura => MediaQuery.of(context).size.width;

  double get altura => MediaQuery.of(context).size.height;

  int get colunas {
    if (desktop) return 5;
    if (tablet) return 3;
    return 1;
  }

  double get cardWidth => (largura / colunas) - 40;

  double get cardHeight => cardWidth * 0.9;

  double get titleSize => cardWidth * 0.10;

  double get subtitleSize => cardWidth * 0.05;

  double get iconSize => cardWidth * 0.15;
}
