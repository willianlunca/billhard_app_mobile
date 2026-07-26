import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:billhard_app_mobile/pages/completar_perfil.dart';
import 'package:billhard_app_mobile/pages/modulos.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';

class PerfilRedirecionamentoService {
  PerfilRedirecionamentoService._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Widget> obterDestinoAposLogin() async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw Exception('Usuário autenticado não encontrado.');
    }

    final perfil = await _supabase
        .from('perfis')
        .select('''
          nome,
          cpf,
          telefone,
          data_nascimento,
          cep,
          estado,
          cidade,
          endereco,
          numero,
          bairro
        ''')
        .eq('id', usuario.id)
        .maybeSingle();

    debugPrint('==========================================');
    debugPrint('VERIFICAÇÃO DO PERFIL');
    debugPrint('Usuário: ${usuario.id}');
    debugPrint('Perfil encontrado: ${perfil != null}');
    debugPrint('Dados do perfil: $perfil');
    debugPrint('==========================================');

    if (perfil == null || !_perfilEstaCompleto(perfil)) {
      await PaginaPersistenteService.salvarPagina('CompletarPerfil');

      return const CompletarPerfil();
    }

    await PaginaPersistenteService.salvarPagina('Modulos');

    return const Modulos();
  }

  static Future<bool> usuarioPossuiPerfilCompleto() async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      return false;
    }

    final perfil = await _supabase
        .from('perfis')
        .select('''
          nome,
          cpf,
          telefone,
          data_nascimento,
          cep,
          estado,
          cidade,
          endereco,
          numero,
          bairro
        ''')
        .eq('id', usuario.id)
        .maybeSingle();

    if (perfil == null) {
      return false;
    }

    return _perfilEstaCompleto(perfil);
  }

  static bool _perfilEstaCompleto(Map<String, dynamic> perfil) {
    const camposObrigatorios = <String>[
      'nome',
      'cpf',
      'telefone',
      'data_nascimento',
      'cep',
      'estado',
      'cidade',
      'endereco',
      'numero',
      'bairro',
    ];

    for (final campo in camposObrigatorios) {
      final valor = perfil[campo];
      final preenchido = _valorEstaPreenchido(valor);

      debugPrint('Campo: $campo | valor: "$valor" | preenchido: $preenchido');

      if (!preenchido) {
        debugPrint('Cadastro incompleto no campo: $campo');
        return false;
      }
    }

    return true;
  }

  static bool _valorEstaPreenchido(dynamic valor) {
    if (valor == null) {
      return false;
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return false;
    }

    if (texto.toLowerCase() == 'null') {
      return false;
    }

    return true;
  }
}
