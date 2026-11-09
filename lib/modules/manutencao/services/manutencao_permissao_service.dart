import 'package:supabase_flutter/supabase_flutter.dart';

import 'manutencao_local_service.dart';

class ManutencaoPermissaoService {
  ManutencaoPermissaoService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  final _local = ManutencaoLocalService();

  Future<bool> temPermissao() async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) return false;

    final armazenamento = await _local.box;
    const chave = 'permissao:manutencao';

    try {
      final resultado = await _supabase
          .from('permissoes_modulos')
          .select('manutencao')
          .eq('user', usuario.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      final autorizado = resultado?['manutencao'] == true;

      await armazenamento.put(chave, autorizado ? 'true' : 'false');

      return autorizado;
    } catch (_) {
      return armazenamento.get(chave) == 'true';
    }
  }

  Future<void> exigirPermissao() async {
    final autorizado = await temPermissao();

    if (!autorizado) {
      throw const ManutencaoAcessoNegadoException();
    }
  }
}

class ManutencaoAcessoNegadoException implements Exception {
  const ManutencaoAcessoNegadoException();

  @override
  String toString() {
    return 'Você não possui permissão para acessar manutenção.';
  }
}
