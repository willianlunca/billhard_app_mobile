import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:billhard_app_mobile/pages/modulos.dart';
import 'package:billhard_app_mobile/pages/equipamentos.dart';
import 'package:billhard_app_mobile/pages/login.dart';
import 'package:billhard_app_mobile/pages/novo_usuario.dart';
import 'package:billhard_app_mobile/pages/recupera_senha.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';
import 'package:lottie/lottie.dart';

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  Widget? destino;

  @override
  void initState() {
    super.initState();
    verificarLogin();
  }

  Future<void> verificarLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    final session = Supabase.instance.client.auth.currentSession;

    //await PaginaPersistenteService.salvarPagina('Novousuario');

    final String paginaSalva = await PaginaPersistenteService.obterPagina();

    if (!mounted) {
      return;
    }

    final Map<String, Widget> paginas = {
      'Modulos': const Modulos(),
      'Equipamentos': const Equipamentos(),
      'Login': const Login(),
      'Novousuario': const Novousuario(),
      'RecuperaSenha': const RecuperaSenha(),
      'Modulos': const Modulos(),
    };

    setState(() {
      if (session == null) {
        destino = const Login();
        return;
      }

      if (paginaSalva.isEmpty || !paginas.containsKey(paginaSalva)) {
        destino = const Modulos();
        return;
      }

      destino = paginas[paginaSalva]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (destino == null) {
      return Scaffold(
        body: Container(
          color: BillhardColors.bege,
          child: Center(
            child: Lottie.asset(
              'assets/animations/animacao_verde_escuro.json',
              width: 100,
              height: 100,
            ),
          ),
        ),
      );
    }

    return destino!;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    //url: 'https://api.nutribreads.com.br',
    url: 'https://api.nutribreads.com.br',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Billhard App',

      // 🌎 pt-BR
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(),
      home: const AuthCheck(),
      //home: const Login(),
      //home: const Colaboradores(),
      //home: const LogistCanhoto(),
      //home: const ListaOrdens(),
      //home: LoadWidget(),
    );
  }
}
