import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:billhard_app_mobile/pages/login.dart';
import 'package:billhard_app_mobile/utils/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billhard_app_mobile/services/cadastro_usuario_service.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';

class Novousuario extends StatefulWidget {
  const Novousuario({super.key});

  @override
  State<Novousuario> createState() => _NovousuarioState();
}

class _NovousuarioState extends State<Novousuario> {
  @override
  //final AuthService _auth = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  final TextEditingController confirmarSenhaController =
      TextEditingController();
  final CadastroUsuarioService _cadastroUsuarioService =
      CadastroUsuarioService();

  final FocusNode senhaFocus = FocusNode();
  final FocusNode confirmarSenhaFocus = FocusNode();

  bool cadastrandoUsuario = false;

  Future<void> _salvarPaginaAtual() async {
    await PaginaPersistenteService.salvarPagina('Novousuario');

    debugPrint('Página Novousuario salva');
  }

  void initState() {
    super.initState();
    _salvarPaginaAtual();
  }

  Future<void> realizarNovousuario() async {
    if (cadastrandoUsuario) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      cadastrandoUsuario = true;
    });

    final ResultadoCadastroUsuario resultado = await _cadastroUsuarioService
        .cadastrarUsuario(
          email: emailController.text,
          senha: senhaController.text,
          confirmarSenha: confirmarSenhaController.text,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      cadastrandoUsuario = false;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(resultado.mensagem)));

    if (!resultado.sucesso) {
      return;
    }

    emailController.clear();
    senhaController.clear();
    confirmarSenhaController.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Login()),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    senhaFocus.dispose();
    confirmarSenhaFocus.dispose();
    super.dispose();
  }

  final session = Supabase.instance.client.auth.currentSession;

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
                    'Crie sua conta',
                    style: GoogleFonts.manrope(
                      fontSize: ui.titleSize * 0.85,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: ui.cardWidth * 0.9,
                  child: Text(
                    'Junte-se à excelencia em infraestrutura tecnológica.',
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
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(
                              context,
                            ).requestFocus(confirmarSenhaFocus);
                          },
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
                  width: ui.cardWidth,
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.07),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CONFIRMAR SENHA',
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
                          controller: confirmarSenhaController,
                          focusNode: confirmarSenhaFocus,
                          obscureText: true,
                          textInputAction: TextInputAction.go,
                          onFieldSubmitted: (_) => realizarNovousuario(),
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
                    onPressed: cadastrandoUsuario
                        ? null
                        : () {
                            realizarNovousuario();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BillhardColors.verdePrincipal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                    child: cadastrandoUsuario
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BillhardColors.bege,
                            ),
                          )
                        : Text(
                            'Cadastrar',
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
                        'Já possui uma conta?',
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
                              builder: (context) => const Login(),
                            ),
                          );
                        },
                        child: Text(
                          'Entrar',
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
