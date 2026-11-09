import 'package:supabase_flutter/supabase_flutter.dart';

class ResultadoRecuperacaoSenha {
  final bool sucesso;
  final String mensagem;

  const ResultadoRecuperacaoSenha({
    required this.sucesso,
    required this.mensagem,
  });
}

class RecuperacaoSenhaService {
  final SupabaseClient _supabase;

  RecuperacaoSenhaService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<ResultadoRecuperacaoSenha> enviarLinkRecuperacao({
    required String email,
    String? redirectTo,
  }) async {
    final String emailTratado = email.trim().toLowerCase();

    final String? erroValidacao = validarEmail(emailTratado);

    if (erroValidacao != null) {
      return ResultadoRecuperacaoSenha(sucesso: false, mensagem: erroValidacao);
    }

    try {
      await _supabase.auth.resetPasswordForEmail(
        emailTratado,
        redirectTo: redirectTo,
      );

      return const ResultadoRecuperacaoSenha(
        sucesso: true,
        mensagem:
            'Link de recuperação enviado. Verifique sua caixa de entrada e a pasta de spam.',
      );
    } on AuthException catch (erro) {
      return ResultadoRecuperacaoSenha(
        sucesso: false,
        mensagem: _traduzirErroSupabase(erro),
      );
    } catch (_) {
      return const ResultadoRecuperacaoSenha(
        sucesso: false,
        mensagem:
            'Não foi possível enviar o link de recuperação. Verifique sua conexão e tente novamente.',
      );
    }
  }

  String? validarEmail(String email) {
    final String emailTratado = email.trim();

    if (emailTratado.isEmpty) {
      return 'Informe seu e-mail.';
    }

    final RegExp regexEmail = RegExp(
      r'^[A-Za-z0-9.!#$%&'
      r"'"
      r'*+/=?^_`{|}~-]+@'
      r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
      r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
    );

    if (!regexEmail.hasMatch(emailTratado)) {
      return 'Informe um endereço de e-mail válido.';
    }

    return null;
  }

  String _traduzirErroSupabase(AuthException erro) {
    final String mensagem = erro.message.toLowerCase();

    if (mensagem.contains('invalid email')) {
      return 'O endereço de e-mail informado é inválido.';
    }

    if (mensagem.contains('email rate limit exceeded') ||
        mensagem.contains('rate limit')) {
      return 'Muitas solicitações foram realizadas. Aguarde alguns minutos e tente novamente.';
    }

    if (mensagem.contains('signup is disabled')) {
      return 'O envio de e-mails está temporariamente desativado.';
    }

    if (mensagem.contains('network') ||
        mensagem.contains('socket') ||
        mensagem.contains('connection')) {
      return 'Não foi possível conectar ao servidor. Verifique sua internet.';
    }

    return erro.message;
  }
}
