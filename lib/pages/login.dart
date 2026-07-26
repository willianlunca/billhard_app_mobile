import 'package:flutter/material.dart';
import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:billhard_app_mobile/pages/novo_usuario.dart';
import 'package:billhard_app_mobile/pages/recupera_senha.dart';
import 'package:billhard_app_mobile/services/login_service.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';
import 'package:billhard_app_mobile/services/perfil_redirecionamento_service.dart';
import 'package:billhard_app_mobile/utils/responsive.dart';
import 'package:google_fonts/google_fonts.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  final FocusNode senhaFocus = FocusNode();

  final LoginService _loginService = LoginService();

  bool realizandoLogin = false;

  Future<void> _salvarPaginaAtual() async {
    await PaginaPersistenteService.salvarPagina('Login');

    debugPrint('Página Login salva');
  }

  @override
  void initState() {
    super.initState();
    _salvarPaginaAtual();
  }

  Future<void> realizarLogin() async {
    if (realizandoLogin) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      realizandoLogin = true;
    });

    final ResultadoLogin resultado = await _loginService.realizarLogin(
      email: emailController.text,
      senha: senhaController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      realizandoLogin = false;
    });

    if (!resultado.sucesso) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao efetuar o login.\n'
            'Erro do Servidor: "${resultado.erro ?? 'Erro desconhecido'}"',
          ),
        ),
      );

      return;
    }

    try {
      final destino =
          await PerfilRedirecionamentoService.obterDestinoAposLogin();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destino),
        (route) => false,
      );
    } catch (erro, stackTrace) {
      debugPrint('Erro ao redirecionar usuário: $erro');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível verificar suas informações pessoais.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    senhaFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = BillhardResponsive(context);

    return Scaffold(
      backgroundColor: BillhardColors.bege,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.3),
                  width: ui.cardWidth * 0.8,
                  child: Image.asset('assets/logo/billhard-versao-1.png'),
                ),
                SizedBox(
                  child: Text(
                    'Acesse sua conta',
                    style: GoogleFonts.manrope(
                      fontSize: ui.titleSize * 0.85,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: ui.cardWidth * 0.9,
                  child: Text(
                    'Bem vindo à excelencia infraestrutura tecnológica.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: ui.titleSize * 0.40,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Container(
                  width: ui.cardWidth,
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.1),
                  child: Row(
                    children: [
                      Text(
                        'E-MAIL',
                        style: GoogleFonts.manrope(
                          fontSize: ui.titleSize * 0.33,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: ui.cardWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        child: TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(senhaFocus);
                          },
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.38,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            hintText: 'exemplo@seu-email.com',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: ui.titleSize * 0.38,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade500,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: ui.cardWidth,
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.07),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SENHA',
                        style: GoogleFonts.manrope(
                          fontSize: ui.titleSize * 0.33,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RecuperaSenha(),
                            ),
                          );
                        },
                        child: Text(
                          'ESQUECEU A SENHA?',
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.25,
                            fontWeight: FontWeight.w700,
                            color: BillhardColors.terraCota,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: ui.cardWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        child: TextFormField(
                          controller: senhaController,
                          focusNode: senhaFocus,
                          obscureText: true,
                          textInputAction: TextInputAction.go,
                          onFieldSubmitted: (_) => realizarLogin(),
                          keyboardType: TextInputType.visiblePassword,
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.38,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: ui.titleSize * 0.38,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade500,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.1),
                  width: ui.cardWidth * 0.98,
                  height: ui.cardHeight * 0.18,
                  child: ElevatedButton(
                    onPressed: realizandoLogin
                        ? null
                        : () {
                            realizarLogin();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BillhardColors.verdePrincipal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                    child: realizandoLogin
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BillhardColors.bege,
                            ),
                          )
                        : Text(
                            'Entrar',
                            style: GoogleFonts.manrope(
                              fontSize: ui.titleSize * 0.60,
                              fontWeight: FontWeight.w800,
                              color: BillhardColors.bege,
                            ),
                          ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.05),
                  width: ui.cardWidth * 0.98,
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade400,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OU',
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.25,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade400,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.02),
                  width: ui.cardWidth * 0.98,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Não possui uma conta?',
                        style: GoogleFonts.manrope(
                          fontSize: ui.titleSize * 0.33,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(width: ui.cardWidth * 0.02),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Novousuario(),
                            ),
                          );
                        },
                        child: Text(
                          'Criar conta',
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.33,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.03),
                  child: Text(
                    '© 2026 BILLHARD SISTEMAS INTELIGENTES. TODOS OS DIREITOS RESERVADOS.',
                    style: GoogleFonts.manrope(
                      fontSize: ui.titleSize * 0.25,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Container(
                  width: ui.cardWidth * 0.70,
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.03),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {},
                        child: Text(
                          'PRIVACIDADE',
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.25,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {},
                        child: Text(
                          'TERMOS',
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.25,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {},
                        child: Text(
                          'SUPORTE',
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.25,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
