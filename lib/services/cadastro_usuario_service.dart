import 'package:supabase_flutter/supabase_flutter.dart';

class ResultadoCadastroUsuario {
  final bool sucesso;
  final String mensagem;
  final User? usuario;

  const ResultadoCadastroUsuario({
    required this.sucesso,
    required this.mensagem,
    this.usuario,
  });
}

class CadastroUsuarioService {
  final SupabaseClient _supabase;

  CadastroUsuarioService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<ResultadoCadastroUsuario> cadastrarUsuario({
    required String email,
    required String senha,
    required String confirmarSenha,
  }) async {
    final String emailTratado = email.trim();

    final String? erroValidacao = _validarDados(
      email: emailTratado,
      senha: senha,
      confirmarSenha: confirmarSenha,
    );

    if (erroValidacao != null) {
      return ResultadoCadastroUsuario(sucesso: false, mensagem: erroValidacao);
    }

    try {
      final AuthResponse resposta = await _supabase.auth.signUp(
        email: emailTratado,
        password: senha,
      );

      final User? usuario = resposta.user;

      if (usuario == null) {
        return const ResultadoCadastroUsuario(
          sucesso: false,
          mensagem: 'Não foi possível criar o usuário.',
        );
      }

      return ResultadoCadastroUsuario(
        sucesso: true,
        mensagem:
            'Conta criada com sucesso. Verifique seu e-mail para confirmar o cadastro.',
        usuario: usuario,
      );
    } on AuthException catch (erro) {
      return ResultadoCadastroUsuario(
        sucesso: false,
        mensagem: _traduzirErroSupabase(erro),
      );
    } catch (erro) {
      return ResultadoCadastroUsuario(
        sucesso: false,
        mensagem: 'Ocorreu um erro inesperado ao criar o usuário: $erro',
      );
    }
  }

  String? _validarDados({
    required String email,
    required String senha,
    required String confirmarSenha,
  }) {
    if (email.isEmpty) {
      return 'Informe seu e-mail.';
    }

    if (!_emailValido(email)) {
      return 'Informe um endereço de e-mail válido.';
    }

    if (senha.isEmpty) {
      return 'Informe sua senha.';
    }

    if (confirmarSenha.isEmpty) {
      return 'Confirme sua senha.';
    }

    if (senha != confirmarSenha) {
      return 'As senhas informadas não são iguais.';
    }

    if (senha.length < 8) {
      return 'A senha deve possuir no mínimo 8 caracteres.';
    }

    if (!_possuiLetraMaiuscula(senha)) {
      return 'A senha deve possuir pelo menos uma letra maiúscula.';
    }

    if (!_possuiCaractereEspecial(senha)) {
      return 'A senha deve possuir pelo menos um caractere especial.';
    }

    return null;
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

  bool _possuiLetraMaiuscula(String senha) {
    return RegExp(r'[A-Z]').hasMatch(senha);
  }

  bool _possuiCaractereEspecial(String senha) {
    return RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=;/\\[\]~`]').hasMatch(senha);
  }

  String _traduzirErroSupabase(AuthException erro) {
    final String mensagem = erro.message.toLowerCase();

    if (mensagem.contains('user already registered') ||
        mensagem.contains('already been registered') ||
        mensagem.contains('already registered')) {
      return 'Este e-mail já possui uma conta cadastrada.';
    }

    if (mensagem.contains('invalid email')) {
      return 'O endereço de e-mail informado é inválido.';
    }

    if (mensagem.contains('password should be at least')) {
      return 'A senha informada não atende aos requisitos mínimos.';
    }

    if (mensagem.contains('signup is disabled')) {
      return 'O cadastro de novos usuários está temporariamente desativado.';
    }

    if (mensagem.contains('email rate limit exceeded') ||
        mensagem.contains('rate limit')) {
      return 'Muitas tentativas foram realizadas. Aguarde alguns minutos e tente novamente.';
    }

    if (mensagem.contains('network') ||
        mensagem.contains('socket') ||
        mensagem.contains('connection')) {
      return 'Não foi possível conectar ao servidor. Verifique sua internet.';
    }

    return erro.message;
  }
}
