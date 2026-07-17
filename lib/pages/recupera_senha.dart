import 'package:flutter/material.dart';
import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:billhard_app_mobile/pages/login.dart';
import 'package:billhard_app_mobile/utils/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billhard_app_mobile/services/recuperacao_senha_service.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';

class RecuperaSenha extends StatefulWidget {
  const RecuperaSenha({super.key});

  @override
  State<RecuperaSenha> createState() => _RecuperaSenhaState();
}

class _RecuperaSenhaState extends State<RecuperaSenha> {
  final TextEditingController emailController = TextEditingController();

  final RecuperacaoSenhaService _recuperacaoSenhaService =
      RecuperacaoSenhaService();

  bool enviandoLink = false;
  Future<void> _salvarPaginaAtual() async {
    await PaginaPersistenteService.salvarPagina('RecuperaSenha');

    debugPrint('Página RecuperaSenha salva');
  }

  void initState() {
    super.initState();
    _salvarPaginaAtual();
  }

  Future<void> realizarRecuperaSenha() async {
    if (enviandoLink) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      enviandoLink = true;
    });

    final ResultadoRecuperacaoSenha resultado = await _recuperacaoSenhaService
        .enviarLinkRecuperacao(
          email: emailController.text,

          // Coloque aqui o endereço da página que receberá o usuário
          // depois que ele clicar no link enviado pelo Supabase.
          //
          // Exemplo para deep link:
          // redirectTo: 'br.com.billhard.mobile://recovery',
          //
          // Exemplo para página web:
          // redirectTo: 'https://seu-dominio.com/recovery.html',
        );

    if (!mounted) {
      return;
    }

    setState(() {
      enviandoLink = false;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(resultado.mensagem)));

    if (!resultado.sucesso) {
      return;
    }

    emailController.clear();
  }

  @override
  void dispose() {
    emailController.dispose();
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
                    'Recuperar senha',
                    style: GoogleFonts.manrope(
                      fontSize: ui.titleSize * 0.85,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: ui.cardWidth * 0.9,
                  child: Text(
                    'Insira seu e-mail cadastrado e enviaremos um link pra você criar uma nova senha.',
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
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.email],
                          onFieldSubmitted: (_) {
                            realizarRecuperaSenha();
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
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.1),
                  width: ui.cardWidth * 0.98,
                  height: ui.cardHeight * 0.18,
                  child: ElevatedButton(
                    onPressed: enviandoLink
                        ? null
                        : () {
                            realizarRecuperaSenha();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BillhardColors.verdePrincipal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                    child: enviandoLink
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BillhardColors.bege,
                            ),
                          )
                        : Text(
                            'Recuperar Senha',
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
                  child: InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const Login()),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          size: 24,
                          color: BillhardColors.verdePrincipal,
                        ),
                        SizedBox(width: ui.cardWidth * 0.02),
                        Text(
                          'Voltar para Entrar',
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.33,
                            fontWeight: FontWeight.w800,
                            color: BillhardColors.verdePrincipal,
                          ),
                        ),
                      ],
                    ),
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
