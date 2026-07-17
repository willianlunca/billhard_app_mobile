import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';
import 'package:billhard_app_mobile/utils/responsive.dart';

class Modulos extends StatefulWidget {
  const Modulos({super.key});

  @override
  State<Modulos> createState() => _ModulosState();
}

class _ModulosState extends State<Modulos> {
  @override
  void initState() {
    super.initState();
    _salvarPaginaAtual();
  }

  Future<void> _salvarPaginaAtual() async {
    await PaginaPersistenteService.salvarPagina('Modulos');

    debugPrint('Página Modulos salva');
  }

  @override
  Widget build(BuildContext context) {
    final ui = BillhardResponsive(context);

    return Scaffold(
      backgroundColor: BillhardColors.bege,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: ui.altura / 3,
                  color: BillhardColors.verdePrincipal,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: ui.cardHeight * 0.12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: ui.cardWidth * 0.20,
                              height: ui.cardHeight * 0.25,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.home_outlined,
                                size: ui.cardWidth * 0.10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: ui.cardHeight * 0.01),
                        width: ui.cardWidth * 0.95,
                        child: Text(
                          'Residencial',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.80,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ui.cardWidth * 0.95,
                        child: Text(
                          'Automação inteligente para conforto, segurança e eficiência energética em sua casa.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.40,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: ui.cardHeight * 0.02),
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BillhardColors.verdeSecundario,
                            foregroundColor: BillhardColors.verdePrincipal,
                            elevation: 8,
                            shadowColor: Colors.black26,
                            minimumSize: Size(
                              ui.cardWidth * 0.40,
                              ui.cardHeight * 0.10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Acessar Modulo',
                            style: TextStyle(
                              fontSize: ui.titleSize * 0.40,
                              fontWeight: FontWeight.w600,
                              color: BillhardColors.verdePrincipal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: double.infinity,
                  height: ui.altura / 3.3,
                  color: BillhardColors.verdeSecundario,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: ui.cardWidth * 0.20,
                            height: ui.cardHeight * 0.25,
                            decoration: BoxDecoration(
                              color: BillhardColors.verdePrincipal.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: BillhardColors.verdePrincipal.withValues(
                                  alpha: 0.20,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.business_outlined,
                              size: ui.cardWidth * 0.10,
                              color: BillhardColors.verdePrincipal,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: ui.cardHeight * 0.01),
                        width: ui.cardWidth * 0.95,
                        child: Text(
                          'Comercial',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.80,
                            fontWeight: FontWeight.w800,
                            color: BillhardColors.verdePrincipal,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ui.cardWidth * 0.95,
                        child: Text(
                          'Soluções inteligentes para escritórios, lojas e estabelecimentos comerciais.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.40,
                            fontWeight: FontWeight.w400,
                            color: BillhardColors.verdePrincipal,
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: ui.cardHeight * 0.02),
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BillhardColors.verdePrincipal,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.black26,
                            minimumSize: Size(
                              ui.cardWidth * 0.40,
                              ui.cardHeight * 0.10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Acessar Modulo',
                            style: TextStyle(
                              fontSize: ui.titleSize * 0.40,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: double.infinity,
                  height: ui.altura / 3.3,
                  color: BillhardColors.terraCota,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: ui.cardWidth * 0.20,
                            height: ui.cardHeight * 0.25,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.factory_outlined,
                              size: ui.cardWidth * 0.10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: ui.cardHeight * 0.01),
                        width: ui.cardWidth * 0.95,
                        child: Text(
                          'Industrial',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.80,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ui.cardWidth * 0.95,
                        child: Text(
                          'Controle de alta precisão para monitoramento de produção e otimização industrial.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.40,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: ui.cardHeight * 0.02),
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BillhardColors.bege,
                            foregroundColor: BillhardColors.verdePrincipal,
                            elevation: 8,
                            shadowColor: Colors.black26,
                            minimumSize: Size(
                              ui.cardWidth * 0.40,
                              ui.cardHeight * 0.10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Acessar Modulo',
                            style: TextStyle(
                              fontSize: ui.titleSize * 0.40,
                              fontWeight: FontWeight.w600,
                              color: BillhardColors.verdePrincipal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: ui.cardHeight * 0.30),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: ui.cardHeight * 0.30,
              decoration: BoxDecoration(
                color: BillhardColors.bege,
                border: Border(
                  top: BorderSide(
                    color: Colors.black.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {
                      print('click');
                    },
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: Image.asset(
                              'assets/icon/PNG/billhard-live-1.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Modulos',
                            style: TextStyle(
                              fontSize: ui.titleSize * 0.25,
                              fontWeight: FontWeight.w700,
                              color: BillhardColors.verdePrincipal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  InkWell(
                    onTap: () {
                      print('click');
                    },
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: Image.asset(
                              'assets/icon/PNG/billhard-qrcode.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Provisionar',
                            style: TextStyle(
                              fontSize: ui.titleSize * 0.25,
                              fontWeight: FontWeight.w700,
                              color: BillhardColors.verdePrincipal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  InkWell(
                    onTap: () {
                      print('click');
                    },
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: Image.asset(
                              'assets/icon/PNG/billhard-suporte-1.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Suporte',
                            style: TextStyle(
                              fontSize: ui.titleSize * 0.25,
                              fontWeight: FontWeight.w700,
                              color: BillhardColors.verdePrincipal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  InkWell(
                    onTap: () {
                      print('click');
                    },
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: Image.asset(
                              'assets/icon/PNG/billhard-usuario-1.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Conta',
                            style: TextStyle(
                              fontSize: ui.titleSize * 0.25,
                              fontWeight: FontWeight.w700,
                              color: BillhardColors.verdePrincipal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
