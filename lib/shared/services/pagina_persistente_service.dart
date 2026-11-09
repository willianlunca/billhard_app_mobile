import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaginaPersistenteService {
  static const String _chavePagina = 'ultima_pagina';

  /// Salva somente o nome da página.
  ///
  /// Exemplos:
  /// PaginaPersistenteService.salvarPagina('Modulos');
  /// PaginaPersistenteService.salvarPagina('Equipamentos');
  static Future<void> salvarPagina(String pagina) async {
    final SharedPreferences preferencias =
        await SharedPreferences.getInstance();

    await preferencias.setString(_chavePagina, pagina);

    debugPrint('Página salva: $pagina');
  }

  /// Retorna o nome da última página salva.
  ///
  /// Se não existir nenhuma página salva, retorna "Modulos".
  static Future<String> obterPagina() async {
    final SharedPreferences preferencias =
        await SharedPreferences.getInstance();

    final String pagina = preferencias.getString(_chavePagina) ?? 'Modulos';

    debugPrint('Página recuperada: $pagina');

    return pagina;
  }

  /// Remove a página salva.
  ///
  /// Pode ser utilizado no logout.
  static Future<void> limparPagina() async {
    final SharedPreferences preferencias =
        await SharedPreferences.getInstance();

    await preferencias.remove(_chavePagina);

    debugPrint('Página salva removida');
  }
}
