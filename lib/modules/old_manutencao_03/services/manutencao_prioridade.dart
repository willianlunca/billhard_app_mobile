import 'package:flutter/material.dart';

class ManutencaoPrioridade {
  static Color cor(dynamic raw) {
    if (raw is int) return Color(0xFF000000 | (raw & 0xFFFFFF));
    final s = '$raw'.replaceFirst('#', '').trim();
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) return Color(int.parse('FF$s', radix: 16));
    return const Color(0xFF00331F);
  }
  static bool prioridade(String nome) =>
      ['não urgente', 'nao urgente', 'urgente', 'muito urgente', 'extremamente urgente',
       'baixa', 'média', 'media', 'alta', 'crítica', 'critica']
      .contains(nome.trim().toLowerCase());
}
