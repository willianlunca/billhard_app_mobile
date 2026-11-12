import 'package:supabase_flutter/supabase_flutter.dart';

class AppManutencaoAcesso {
  final bool agenda;
  final bool chamados;
  final bool solicitar;
  const AppManutencaoAcesso({required this.agenda, required this.chamados, required this.solicitar});
  bool get algum => agenda || chamados || solicitar;
}

class AppManutencaoAcessoService {
  final SupabaseClient _db;
  AppManutencaoAcessoService({SupabaseClient? supabase}) : _db = supabase ?? Supabase.instance.client;

  Future<AppManutencaoAcesso> carregar() async {
    final usuario = _db.auth.currentUser;
    if (usuario == null) throw StateError('Usuário não autenticado.');
    final row = await _db.from('app_manutencao')
        .select('agenda, chamados, solicitar')
        .eq('user', usuario.id).maybeSingle();
    return AppManutencaoAcesso(
      agenda: row?['agenda'] == true,
      chamados: row?['chamados'] == true,
      solicitar: row?['solicitar'] == true,
    );
  }
}
