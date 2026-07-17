import 'package:flutter/material.dart';

/// Paleta oficial Nutribreads (Brandkit RGB)
/// Fonte: Nutribreads_brandkit rgb.pdf
///
/// Best practice:
/// - Centralizar TODAS as cores aqui.
/// - Manter nomes consistentes (palette) e também aliases semânticos (theme).
/// - Usar `const` para evitar alocação em runtime.
abstract final class NutribreadsColors {
  NutribreadsColors._();

  // ===== Base (assinatura de marca) =====
  static const Color preto = Color(0xFF000000);
  static const Color branco = Color(0xFFFFFFFF);

  // ===== Paleta (nomes do brandkit) =====
  // Azul
  static const Color azulEscuro = Color(0xFF3A0CA3); // HEX #3a0ca3
  static const Color azulMedio = Color(0xFF4361EE); // HEX #4361ee
  static const Color azulClaro = Color(0xFF4CC9F0); // HEX #4cc9f0

  // Vermelho
  static const Color vermelhoEscuro = Color(0xFF780000); // HEX #780000
  static const Color vermelhoMedio = Color(0xFFC31123); // HEX #c31123
  static const Color vermelhoClaro = Color(0xFFFFA5AB); // HEX #ffa5ab

  // Quentes
  static const Color amarelo = Color(0xFFFFCC66); // HEX #ffcc66
  static const Color laranja = Color(0xFFFB8B24); // HEX #fb8b24

  // Roxo
  static const Color roxo = Color(0xFFB5179E); // HEX #b5179e

  // ===== Aliases semânticos (para usar em ThemeData e PDFs) =====
  // Ajuste se quiser outro "primary" como padrão do app.
  static const Color primary = azulMedio;
  static const Color primaryDark = azulEscuro;
  static const Color primaryLight = azulClaro;

  static const Color accent = roxo;

  static const Color success = azulClaro;
  static const Color warning = amarelo;
  static const Color danger = vermelhoMedio;

  static const Color backgroundLight = branco;
  static const Color backgroundDark = preto;

  static const Color textOnDark = branco;
  static const Color textOnLight = preto;
}

abstract final class BillhardColors {
  BillhardColors._();

  static const Color verdePrincipal = Color(0xFF00331F);
  static const Color verdeSecundario = Color(0xFFB2DBCD);
  static const Color terraCota = Color(0xFFA94B2F);
  static const Color bege = Color(0xFFE2DECC);
  static const Color azulTermokip = Color(0xFFB7C9E5);
}
