import 'package:supabase_flutter/supabase_flutter.dart';

class ResultadoLogin {
  final bool sucesso;
  final String? erro;
  final User? usuario;
  final Session? sessao;

  const ResultadoLogin({
    required this.sucesso,
    this.erro,
    this.usuario,
    this.sessao,
  });
}

class LoginService {
  final SupabaseClient _supabase;

  LoginService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<ResultadoLogin> realizarLogin({
    required String email,
    required String senha,
  }) async {
    final String emailTratado = email.trim().toLowerCase();

    if (emailTratado.isEmpty) {
      return const ResultadoLogin(sucesso: false, erro: 'Informe seu e-mail.');
    }

    if (!_emailValido(emailTratado)) {
      return const ResultadoLogin(
        sucesso: false,
        erro: 'O e-mail informado não é válido.',
      );
    }

    if (senha.isEmpty) {
      return const ResultadoLogin(sucesso: false, erro: 'Informe sua senha.');
    }

    try {
      final AuthResponse resposta = await _supabase.auth.signInWithPassword(
        email: emailTratado,
        password: senha,
      );

      if (resposta.user == null || resposta.session == null) {
        return const ResultadoLogin(
          sucesso: false,
          erro:
              'Não foi possível realizar o login. O servidor não retornou uma sessão válida.',
        );
      }

      return ResultadoLogin(
        sucesso: true,
        usuario: resposta.user,
        sessao: resposta.session,
      );
    } on AuthException catch (erro) {
      return ResultadoLogin(sucesso: false, erro: erro.message);
    } catch (erro) {
      return ResultadoLogin(sucesso: false, erro: erro.toString());
    }
  }

  bool _emailValido(String email) {
    final RegExp regexEmail = RegExp(
      r'^[A-Za-z0-9.!#$%&'
      r"'"
      r'*+/=?^_`{|}~-]+@'
      r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
      r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
    );

    return regexEmail.hasMatch(email);
  }
}
