import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:billhard_app_mobile/pages/login.dart';
import 'package:billhard_app_mobile/services/cep_service.dart';
import 'package:billhard_app_mobile/services/documento_validator.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';
import 'package:billhard_app_mobile/utils/perfil_input_formatters.dart';
import 'package:billhard_app_mobile/utils/seletor_data_nascimento.dart';
import 'package:billhard_app_mobile/utils/responsive.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Conta extends StatefulWidget {
  const Conta({super.key});

  @override
  State<Conta> createState() => _ContaState();
}

class _ContaState extends State<Conta> {
  final _formKey = GlobalKey<FormState>();

  bool modoEdicao = false;
  bool carregandoCidades = false;
  bool buscandoCep = false;
  bool fazendoLogout = false;
  bool excluindoConta = false;
  bool carregandoPerfil = true;
  bool salvandoPerfil = false;

  String? ultimoCepConsultado;

  String versaoApp = '';
  String numeroBuild = '';

  final FocusNode senhaFocus = FocusNode();

  final TextEditingController nomeController = TextEditingController();

  final TextEditingController cpfController = TextEditingController();

  final TextEditingController rgController = TextEditingController();
  final TextEditingController telefoneController = TextEditingController();

  final TextEditingController cepController = TextEditingController();

  final TextEditingController enderecoController = TextEditingController();

  final TextEditingController dataNascimentoController =
      TextEditingController();

  final TextEditingController bairroController = TextEditingController();

  final TextEditingController numeroController = TextEditingController();

  final TextEditingController complementoController = TextEditingController();

  String? estadoSelecionado;
  String? cidadeSelecionada;

  List<String> cidades = [];

  final List<String> estados = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  @override
  void initState() {
    super.initState();

    _salvarPaginaAtual();
    carregarVersaoApp();
    carregarPerfil();
  }

  Future<void> carregarVersaoApp() async {
    try {
      final informacoes = await PackageInfo.fromPlatform();

      if (!mounted) {
        return;
      }

      setState(() {
        versaoApp = informacoes.version;
        numeroBuild = informacoes.buildNumber;
      });
    } catch (erro, stackTrace) {
      debugPrint('Erro ao carregar versão do aplicativo: $erro');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> carregarPerfil() async {
    final supabase = Supabase.instance.client;
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      if (mounted) {
        setState(() {
          carregandoPerfil = false;
        });
      }
      return;
    }

    try {
      final perfil = await supabase
          .from('perfis')
          .select('''
          id,
          nome,
          cpf,
          telefone,
          email,
          rg,
          data_nascimento,
          cep,
          estado,
          cidade,
          endereco,
          numero,
          bairro,
          complemento,
          ativo,
          ultimo_acesso,
          criado_em,
          atualizado_em
          ''')
          .eq('id', usuario.id)
          .maybeSingle();

      if (perfil == null) {
        throw Exception(
          'Seu usuário existe, mas o perfil ainda não foi criado no banco.',
        );
      }

      nomeController.text = perfil['nome']?.toString() ?? '';
      cpfController.text = perfil['cpf']?.toString() ?? '';
      telefoneController.text = perfil['telefone']?.toString() ?? '';
      rgController.text = perfil['rg']?.toString() ?? '';
      cepController.text = perfil['cep']?.toString() ?? '';
      enderecoController.text = perfil['endereco']?.toString() ?? '';
      numeroController.text = perfil['numero']?.toString() ?? '';
      bairroController.text = perfil['bairro']?.toString() ?? '';
      complementoController.text = perfil['complemento']?.toString() ?? '';

      final dataNascimento = perfil['data_nascimento']?.toString();

      if (dataNascimento != null && dataNascimento.isNotEmpty) {
        final data = DateTime.tryParse(dataNascimento);

        if (data != null) {
          dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(data);
        }
      } else {
        dataNascimentoController.clear();
      }

      final estado = perfil['estado']?.toString();
      final cidade = perfil['cidade']?.toString();

      if (!mounted) {
        return;
      }

      setState(() {
        estadoSelecionado = estado != null && estados.contains(estado)
            ? estado
            : null;

        cidadeSelecionada = null;
      });

      if (estadoSelecionado != null) {
        await carregarCidades(estadoSelecionado!, cidadeParaSelecionar: cidade);
      }
    } on PostgrestException catch (erro, stackTrace) {
      debugPrint('Erro do Supabase ao carregar perfil: ${erro.message}');
      debugPrint('Código: ${erro.code}');
      debugPrint('Detalhes: ${erro.details}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            erro.message.isNotEmpty
                ? erro.message
                : 'Não foi possível carregar o perfil.',
          ),
        ),
      );
    } catch (erro, stackTrace) {
      debugPrint('Erro ao carregar perfil: $erro');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          carregandoPerfil = false;
        });
      }
    }
  }

  Future<void> salvarPerfil() async {
    if (salvandoPerfil) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final supabase = Supabase.instance.client;
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sua sessão expirou. Entre novamente.')),
      );
      return;
    }

    final nome = nomeController.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe seu nome completo.')),
      );
      return;
    }

    DateTime? dataNascimento;

    final dataNascimentoTexto = dataNascimentoController.text.trim();

    if (dataNascimentoTexto.isNotEmpty) {
      try {
        dataNascimento = DateFormat(
          'dd/MM/yyyy',
        ).parseStrict(dataNascimentoTexto);
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A data de nascimento é inválida.')),
        );
        return;
      }
    }

    setState(() {
      salvandoPerfil = true;
    });

    try {
      final perfisAtualizados = await supabase
          .from('perfis')
          .update({
            'nome': nome,
            'cpf': _textoOuNull(cpfController.text),
            'telefone': _textoOuNull(telefoneController.text),
            'rg': _textoOuNull(rgController.text),
            'data_nascimento': dataNascimento == null
                ? null
                : DateFormat('yyyy-MM-dd').format(dataNascimento),
            'cep': _textoOuNull(cepController.text),
            'estado': estadoSelecionado,
            'cidade': cidadeSelecionada,
            'endereco': _textoOuNull(enderecoController.text),
            'numero': _textoOuNull(numeroController.text),
            'bairro': _textoOuNull(bairroController.text),
            'complemento': _textoOuNull(complementoController.text),
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', usuario.id)
          .select('id');

      if (perfisAtualizados.isEmpty) {
        throw Exception(
          'O perfil deste usuário não existe ou não pode ser atualizado.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        modoEdicao = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Informações atualizadas com sucesso.')),
        );
    } on PostgrestException catch (erro, stackTrace) {
      debugPrint('Erro do Supabase ao salvar perfil: ${erro.message}');
      debugPrint('Código: ${erro.code}');
      debugPrint('Detalhes: ${erro.details}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              erro.message.isNotEmpty
                  ? erro.message
                  : 'Não foi possível salvar o perfil.',
            ),
          ),
        );
    } catch (erro, stackTrace) {
      debugPrint('Erro inesperado ao salvar perfil: $erro');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar as informações.'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          salvandoPerfil = false;
        });
      }
    }
  }

  String? _textoOuNull(String texto) {
    final valor = texto.trim();
    return valor.isEmpty ? null : valor;
  }

  String _obterIniciais(String nome) {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();

    if (partes.isEmpty) {
      return 'BH';
    }

    if (partes.length == 1) {
      final primeira = partes.first;

      if (primeira.length == 1) {
        return primeira.toUpperCase();
      }

      return primeira.substring(0, 2).toUpperCase();
    }

    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  void _irParaLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Login()),
      (route) => false,
    );
  }

  Future<void> fazerLogout() async {
    if (fazendoLogout) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      fazendoLogout = true;
    });

    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) {
        return;
      }

      _irParaLogin();
    } on AuthException catch (erro) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            erro.message.isNotEmpty
                ? erro.message
                : 'Não foi possível sair da conta.',
          ),
        ),
      );
    } catch (erro, stackTrace) {
      debugPrint('Erro ao realizar logout: $erro');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível sair da conta.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          fazendoLogout = false;
        });
      }
    }
  }

  Future<void> confirmarLogout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: _temaBillhard(),
          child: AlertDialog(
            backgroundColor: BillhardColors.bege,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Sair da conta?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: BillhardColors.verdePrincipal,
              ),
            ),
            content: const Text(
              'Você precisará informar novamente seu e-mail e senha para acessar o aplicativo.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('CANCELAR'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text(
                  'SAIR',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: BillhardColors.terraCota,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmar == true && mounted) {
      await fazerLogout();
    }
  }

  Future<void> excluirConta() async {
    if (excluindoConta) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      excluindoConta = true;
    });

    final supabase = Supabase.instance.client;

    try {
      final sessao = supabase.auth.currentSession;
      final usuario = supabase.auth.currentUser;

      if (sessao == null || usuario == null) {
        throw Exception(
          'Sua sessão expirou. Entre novamente para excluir sua conta.',
        );
      }

      debugPrint('==========================================');
      debugPrint('INICIANDO EXCLUSÃO DA CONTA');
      debugPrint('Usuário: ${usuario.id}');
      debugPrint('E-mail: ${usuario.email}');
      debugPrint('==========================================');

      final resposta = await supabase.functions.invoke(
        'delete-account',
        method: HttpMethod.post,
        headers: {
          'Authorization': 'Bearer ${sessao.accessToken}',
          'Content-Type': 'application/json',
        },
        body: {'confirmar_exclusao': true},
      );

      debugPrint('Status da exclusão: ${resposta.status}');
      debugPrint('Resposta da exclusão: ${resposta.data}');

      if (resposta.status < 200 || resposta.status >= 300) {
        throw Exception(_mensagemRespostaExclusao(resposta.data));
      }

      if (resposta.data is Map) {
        final dados = Map<String, dynamic>.from(resposta.data as Map);

        if (dados['sucesso'] != true) {
          throw Exception(
            dados['message']?.toString() ??
                dados['erro']?.toString() ??
                'O servidor não confirmou a exclusão da conta.',
          );
        }
      }

      /*
     * A Edge Function já deve ter excluído o usuário
     * no Supabase Auth.
     *
     * Aqui limpamos somente os dados locais da sessão.
     */
      try {
        await supabase.auth.signOut(scope: SignOutScope.local);
      } catch (erro) {
        /*
       * Após a exclusão no servidor, o signOut pode
       * eventualmente retornar erro porque o usuário
       * já não existe mais. Isso não deve impedir
       * o retorno para o Login.
       */
        debugPrint('Aviso ao limpar sessão após exclusão: $erro');
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua conta foi excluída permanentemente.'),
        ),
      );

      _irParaLogin();
    } on FunctionException catch (erro, stackTrace) {
      debugPrint('==========================================');
      debugPrint('ERRO NA EDGE FUNCTION excluir-conta');
      debugPrint('Status: ${erro.status}');
      debugPrint('Reason phrase: ${erro.reasonPhrase}');
      debugPrint('Detalhes: ${erro.details}');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('==========================================');

      if (!mounted) {
        return;
      }

      final mensagem = _mensagemFunctionException(erro);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(mensagem),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
    } on AuthException catch (erro, stackTrace) {
      debugPrint('Erro de autenticação: ${erro.message}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Sua sessão expirou. Entre novamente e tente excluir a conta.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (erro, stackTrace) {
      debugPrint('Erro inesperado ao excluir conta: $erro');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      final mensagem = erro.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              mensagem.isEmpty
                  ? 'Não foi possível excluir sua conta.'
                  : mensagem,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          excluindoConta = false;
        });
      }
    }
  }

  String _mensagemFunctionException(FunctionException erro) {
    final textoDetalhes = erro.details?.toString() ?? '';

    final textoCompleto = '${erro.reasonPhrase ?? ''} $textoDetalhes'
        .toLowerCase();

    if (textoCompleto.contains('invalidworkercreation') ||
        textoCompleto.contains('worker boot error') ||
        textoCompleto.contains('failed to read path') ||
        textoCompleto.contains('no such file or directory')) {
      return 'O serviço de exclusão da conta está indisponível no momento. '
          'Tente novamente mais tarde.';
    }

    if (erro.status == 401) {
      return 'Sua sessão expirou. Entre novamente e tente excluir a conta.';
    }

    if (erro.status == 403) {
      return 'Você não possui autorização para executar esta operação.';
    }

    if (erro.status == 404) {
      return 'O serviço de exclusão da conta não foi encontrado.';
    }

    if (erro.status == 500 || erro.status == 503) {
      return 'O servidor não conseguiu processar a exclusão da conta.';
    }

    if (erro.details is Map) {
      final dados = Map<String, dynamic>.from(erro.details as Map);

      final mensagem =
          dados['message']?.toString() ??
          dados['erro']?.toString() ??
          dados['msg']?.toString();

      if (mensagem != null && mensagem.isNotEmpty) {
        return mensagem;
      }
    }

    return 'Não foi possível excluir sua conta. Tente novamente.';
  }

  String _mensagemRespostaExclusao(dynamic dados) {
    if (dados is Map) {
      final mapa = Map<String, dynamic>.from(dados);

      return mapa['message']?.toString() ??
          mapa['erro']?.toString() ??
          mapa['msg']?.toString() ??
          'Não foi possível excluir sua conta.';
    }

    if (dados is String && dados.trim().isNotEmpty) {
      final texto = dados.toLowerCase();

      if (texto.contains('invalidworkercreation') ||
          texto.contains('worker boot error') ||
          texto.contains('failed to read path')) {
        return 'O serviço de exclusão da conta está indisponível no momento.';
      }

      return dados;
    }

    return 'Não foi possível excluir sua conta.';
  }

  Future<void> confirmarExclusaoConta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: !excluindoConta,
      builder: (dialogContext) {
        return Theme(
          data: _temaBillhard(),
          child: AlertDialog(
            backgroundColor: BillhardColors.bege,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 42,
            ),
            title: const Text(
              'Excluir sua conta?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red),
            ),
            content: const Text(
              'Esta ação é permanente. Seus dados e seu acesso ao aplicativo serão removidos.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text(
                  'CANCELAR',
                  style: TextStyle(
                    color: BillhardColors.verdePrincipal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text(
                  'EXCLUIR',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmar == true && mounted) {
      await excluirConta();
    }
  }

  Future<void> buscarEnderecoPeloCep() async {
    final cep = cepController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cep.length != 8) {
      return;
    }

    if (buscandoCep) {
      return;
    }

    if (ultimoCepConsultado == cep) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      buscandoCep = true;
    });

    try {
      final endereco = await CepService.buscarEndereco(cep);

      debugPrint('''
================ RETORNO DO CEP =================
CEP..........: ${endereco.cep}
Logradouro...: ${endereco.logradouro}
Complemento..: ${endereco.complemento}
Bairro.......: ${endereco.bairro}
Cidade.......: ${endereco.cidade}
UF...........: ${endereco.uf}
Estado.......: ${endereco.estado}
IBGE.........: ${endereco.ibge}
DDD..........: ${endereco.ddd}
================================================
''');

      if (!mounted) {
        return;
      }

      setState(() {
        estadoSelecionado = endereco.uf;
        cidadeSelecionada = null;

        cepController.text = endereco.cep;
        enderecoController.text = endereco.logradouro;
        bairroController.text = endereco.bairro;

        if (endereco.complemento.isNotEmpty) {
          complementoController.text = endereco.complemento;
        }
      });

      await carregarCidades(endereco.uf, cidadeParaSelecionar: endereco.cidade);

      if (!mounted) {
        return;
      }

      debugPrint('''
============= RESULTADO DA SELEÇÃO =============
Cidade retornada pelo CEP: ${endereco.cidade}
Cidade selecionada........: $cidadeSelecionada
Estado selecionado........: $estadoSelecionado
Quantidade de cidades.....: ${cidades.length}
Cidade existe na lista....: ${cidades.contains(endereco.cidade)}
================================================
''');

      setState(() {
        ultimoCepConsultado = cep;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endereço localizado com sucesso.')),
      );
    } on CepException catch (erro) {
      debugPrint('Erro ao buscar CEP: ${erro.mensagem}');

      if (!mounted) {
        return;
      }

      setState(() {
        ultimoCepConsultado = null;

        enderecoController.clear();
        bairroController.clear();

        estadoSelecionado = null;
        cidadeSelecionada = null;
        cidades = [];
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(erro.mensagem)));
    } catch (erro, stackTrace) {
      debugPrint('Erro inesperado na consulta do CEP: $erro');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorreu um erro inesperado ao consultar o CEP.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          buscandoCep = false;
        });
      }
    }
  }

  Future<void> _salvarPaginaAtual() async {
    await PaginaPersistenteService.salvarPagina('Conta');

    debugPrint('Página Conta salva');
  }

  Future<void> editarOuSalvarPerfil() async {
    if (carregandoPerfil || salvandoPerfil) {
      return;
    }

    // Primeiro clique: apenas libera os campos.
    if (!modoEdicao) {
      setState(() {
        modoEdicao = true;
      });

      debugPrint('Modo de edição habilitado');
      return;
    }

    // Segundo clique: salva as alterações.
    FocusManager.instance.primaryFocus?.unfocus();

    await salvarPerfil();
  }

  Future<void> carregarCidades(
    String estado, {
    String? cidadeParaSelecionar,
  }) async {
    if (estado.isEmpty) {
      return;
    }

    debugPrint('Iniciando carregamento das cidades de $estado');
    debugPrint('Cidade que deverá ser selecionada: $cidadeParaSelecionar');

    setState(() {
      carregandoCidades = true;
      cidadeSelecionada = null;
      cidades = [];
    });

    try {
      final url = Uri.parse(
        'https://servicodados.ibge.gov.br/api/v1/localidades/'
        'estados/$estado/municipios?orderBy=nome',
      );

      final resposta = await http.get(url).timeout(const Duration(seconds: 10));

      debugPrint('Status da consulta ao IBGE: ${resposta.statusCode}');

      if (resposta.statusCode != 200) {
        throw Exception('Erro ao carregar cidades.');
      }

      final List<dynamic> dados = jsonDecode(utf8.decode(resposta.bodyBytes));

      final novasCidades = dados
          .map((cidade) => cidade['nome'].toString())
          .toList();

      debugPrint(
        'Quantidade de cidades retornadas pelo IBGE: '
        '${novasCidades.length}',
      );

      String? cidadeEncontrada;

      if (cidadeParaSelecionar != null &&
          cidadeParaSelecionar.trim().isNotEmpty) {
        final cidadeProcurada = cidadeParaSelecionar.trim().toLowerCase();

        debugPrint('Procurando cidade normalizada: $cidadeProcurada');

        for (final cidade in novasCidades) {
          if (cidade.trim().toLowerCase() == cidadeProcurada) {
            cidadeEncontrada = cidade;
            break;
          }
        }
      }

      debugPrint('Cidade encontrada na lista do IBGE: $cidadeEncontrada');

      if (!mounted) {
        return;
      }

      setState(() {
        cidades = novasCidades;
        cidadeSelecionada = cidadeEncontrada;
      });

      debugPrint('cidadeSelecionada após setState: $cidadeSelecionada');
    } catch (erro, stackTrace) {
      debugPrint('Erro ao carregar cidades: $erro');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar as cidades.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          carregandoCidades = false;
        });
      }
    }
  }

  Future<void> selecionarDataNascimento() async {
    final data = await SeletorDataNascimento.selecionar(
      context: context,
      dataAtual: dataNascimentoController.text,
    );

    if (data != null) {
      dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(data);
    }
  }

  ThemeData _temaBillhard() {
    return Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(
        primary: BillhardColors.verdePrincipal,
        onPrimary: Colors.white,
        surface: BillhardColors.bege,
        onSurface: Color(0xFF3D403B),
        secondary: BillhardColors.terraCota,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BillhardColors.bege,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _temaCalendarioBillhard(BuildContext context, Widget? child) {
    return Theme(
      data: _temaBillhard().copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: BillhardColors.verdePrincipal,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: child!,
    );
  }

  InputDecoration inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.manrope(
        fontWeight: FontWeight.w400,
        color: Colors.grey.shade500,
      ),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(
          color: BillhardColors.verdePrincipal,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
    );
  }

  Widget tituloCampo({
    required String titulo,
    required BillhardResponsive ui,
    double margemTop = 10,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: margemTop, bottom: 5),
      child: Text(
        titulo,
        style: GoogleFonts.manrope(
          fontSize: ui.titleSize * 0.33,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget campoObrigatorio({
    required TextEditingController controller,
    required String hint,
    required TextStyle estilo,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return IgnorePointer(
      ignoring: !modoEdicao,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        readOnly: readOnly || !modoEdicao,
        onTap: onTap,
        onChanged: onChanged,
        validator: validator,
        style: estilo,
        textAlignVertical: TextAlignVertical.center,
        decoration: inputDecoration(hintText: hint, suffixIcon: suffixIcon),
      ),
    );
  }

  @override
  void dispose() {
    senhaFocus.dispose();

    nomeController.dispose();
    cpfController.dispose();
    rgController.dispose();
    telefoneController.dispose();
    cepController.dispose();
    enderecoController.dispose();
    dataNascimentoController.dispose();
    bairroController.dispose();
    numeroController.dispose();
    complementoController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = BillhardResponsive(context);

    final estiloInput = GoogleFonts.manrope(
      fontSize: ui.titleSize * 0.38,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    );

    if (carregandoPerfil) {
      return const Scaffold(
        backgroundColor: BillhardColors.bege,
        body: Center(
          child: CircularProgressIndicator(
            color: BillhardColors.verdePrincipal,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: BillhardColors.bege,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: (MediaQuery.sizeOf(context).width - ui.cardWidth) / 2,
                right: (MediaQuery.sizeOf(context).width - ui.cardWidth) / 2,
                top: ui.cardHeight * 0.05,
                bottom: ui.cardHeight * 0.12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: ui.cardWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Sair da conta',
                        onPressed: fazendoLogout ? null : confirmarLogout,
                        icon: fazendoLogout
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: BillhardColors.terraCota,
                                ),
                              )
                            : const Icon(
                                Icons.logout_rounded,
                                color: BillhardColors.terraCota,
                              ),
                      ),
                    ),
                  ),
                  Container(
                    width: ui.cardWidth * 0.3,
                    height: ui.cardWidth * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BillhardColors.bege,
                      border: Border.all(color: Colors.grey.shade500),
                    ),
                    foregroundDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _obterIniciais(nomeController.text),
                      style: TextStyle(
                        fontSize: ui.titleSize * 0.8,
                        fontWeight: FontWeight.w700,
                        color: BillhardColors.verdePrincipal,
                      ),
                    ),
                  ),
                  SizedBox(height: ui.cardHeight * 0.015),
                  Text(
                    nomeController.text.trim().isEmpty
                        ? 'Usuário Billhard'
                        : nomeController.text.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: ui.titleSize * 0.65,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: ui.cardHeight * 0.008),
                  Text(
                    'Gerencie suas informações pessoais',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: ui.titleSize * 0.34,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: ui.cardHeight * 0.05),

                  _secao(
                    ui: ui,
                    icone: Icons.account_circle_outlined,
                    titulo: 'INFORMAÇÕES PESSOAIS',
                  ),

                  tituloCampo(titulo: 'NOME COMPLETO', ui: ui),
                  campoObrigatorio(
                    controller: nomeController,
                    hint: 'Seu nome completo',
                    estilo: estiloInput,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[a-zA-ZÀ-ÿ\s'-]"),
                      ),
                      LengthLimitingTextInputFormatter(60),
                      NameInputFormatter(),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe seu nome completo';
                      }
                      return null;
                    },
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            tituloCampo(titulo: 'CPF', ui: ui),
                            campoObrigatorio(
                              controller: cpfController,
                              hint: '000.000.000-00',
                              estilo: estiloInput,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CpfInputFormatter()],
                              validator: (valor) {
                                if (valor == null || valor.trim().isEmpty) {
                                  return 'Informe o CPF';
                                }
                                if (!DocumentoValidator.cpfValido(valor)) {
                                  return 'CPF inválido';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            tituloCampo(titulo: 'RG', ui: ui),
                            campoObrigatorio(
                              controller: rgController,
                              hint: '00.000.000-0',
                              estilo: estiloInput,
                              keyboardType: TextInputType.text,
                              inputFormatters: [RgInputFormatter()],
                              validator: (valor) {
                                if (valor == null || valor.trim().isEmpty) {
                                  return 'Informe o RG';
                                }
                                if (!DocumentoValidator.rgFormatoValido(
                                  valor,
                                )) {
                                  return 'RG inválido';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  tituloCampo(titulo: 'TELEFONE', ui: ui),
                  campoObrigatorio(
                    controller: telefoneController,
                    hint: '(00) 00000-0000',
                    estilo: estiloInput,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9()+\-\s]'),
                      ),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    validator: (valor) {
                      final numeros =
                          valor?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                      if (numeros.length < 10) {
                        return 'Informe um telefone válido';
                      }
                      return null;
                    },
                  ),

                  tituloCampo(titulo: 'DATA DE NASCIMENTO', ui: ui),
                  campoObrigatorio(
                    controller: dataNascimentoController,
                    hint: '00/00/0000',
                    estilo: estiloInput,
                    readOnly: true,
                    onTap: modoEdicao ? selecionarDataNascimento : null,
                    suffixIcon: const Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.grey,
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe sua data de nascimento';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: ui.cardHeight * 0.04),
                  _secao(
                    ui: ui,
                    icone: Icons.place_outlined,
                    titulo: 'ENDEREÇO',
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            tituloCampo(titulo: 'CEP', ui: ui),
                            campoObrigatorio(
                              controller: cepController,
                              hint: '00000-000',
                              estilo: estiloInput,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CepInputFormatter()],
                              suffixIcon: buscandoCep
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.search_outlined,
                                      color: Colors.grey,
                                    ),
                              onChanged: (valor) {
                                final cep = valor.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
                                if (cep.length < 8) {
                                  ultimoCepConsultado = null;
                                }
                                if (cep.length == 8) {
                                  buscarEnderecoPeloCep();
                                }
                              },
                              validator: (valor) {
                                final cep =
                                    valor?.replaceAll(RegExp(r'[^0-9]'), '') ??
                                    '';
                                if (cep.length != 8) {
                                  return 'CEP inválido';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            tituloCampo(titulo: 'ESTADO', ui: ui),
                            IgnorePointer(
                              ignoring: !modoEdicao,
                              child: DropdownButtonFormField<String>(
                                value: estadoSelecionado,
                                isExpanded: true,
                                style: estiloInput,
                                decoration: inputDecoration(hintText: 'Estado'),
                                items: estados
                                    .map(
                                      (estado) => DropdownMenuItem(
                                        value: estado,
                                        child: Text(estado),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (estado) {
                                  if (estado == null) return;
                                  setState(() => estadoSelecionado = estado);
                                  carregarCidades(estado);
                                },
                                validator: (valor) =>
                                    valor == null ? 'Selecione o estado' : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  tituloCampo(titulo: 'CIDADE', ui: ui),
                  IgnorePointer(
                    ignoring: !modoEdicao || carregandoCidades,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        '$estadoSelecionado-$cidadeSelecionada-${cidades.length}',
                      ),
                      value: cidadeSelecionada,
                      isExpanded: true,
                      style: estiloInput,
                      decoration: inputDecoration(
                        hintText: carregandoCidades
                            ? 'Carregando cidades...'
                            : estadoSelecionado == null
                            ? 'Selecione o estado'
                            : 'Selecione a cidade',
                        suffixIcon: carregandoCidades
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      items: cidades
                          .map(
                            (cidade) => DropdownMenuItem(
                              value: cidade,
                              child: Text(
                                cidade,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: carregandoCidades
                          ? null
                          : (cidade) {
                              setState(() => cidadeSelecionada = cidade);
                            },
                      validator: (valor) =>
                          valor == null ? 'Selecione a cidade' : null,
                    ),
                  ),

                  tituloCampo(titulo: 'ENDEREÇO', ui: ui),
                  campoObrigatorio(
                    controller: enderecoController,
                    hint: 'Rua ou avenida',
                    estilo: estiloInput,
                    keyboardType: TextInputType.streetAddress,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(120)],
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe o endereço';
                      }
                      return null;
                    },
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            tituloCampo(titulo: 'NÚMERO', ui: ui),
                            campoObrigatorio(
                              controller: numeroController,
                              hint: 'Número',
                              estilo: estiloInput,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (valor) {
                                if (valor == null || valor.trim().isEmpty) {
                                  return 'Informe o número';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            tituloCampo(titulo: 'BAIRRO', ui: ui),
                            campoObrigatorio(
                              controller: bairroController,
                              hint: 'Bairro',
                              estilo: estiloInput,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(60),
                              ],
                              validator: (valor) {
                                if (valor == null || valor.trim().isEmpty) {
                                  return 'Informe o bairro';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  tituloCampo(titulo: 'COMPLEMENTO', ui: ui),
                  campoObrigatorio(
                    controller: complementoController,
                    hint: 'Apartamento, bloco, sala ou referência',
                    estilo: estiloInput,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  ),

                  SizedBox(height: ui.cardHeight * 0.07),
                  SizedBox(
                    width: ui.cardWidth,
                    height: ui.cardHeight * 0.15,
                    child: ElevatedButton.icon(
                      onPressed: carregandoPerfil || salvandoPerfil
                          ? null
                          : editarOuSalvarPerfil,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: modoEdicao
                            ? BillhardColors.verdePrincipal
                            : BillhardColors.terraCota,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: salvandoPerfil
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              modoEdicao
                                  ? Icons.save_outlined
                                  : Icons.edit_outlined,
                            ),
                      label: Text(
                        salvandoPerfil
                            ? 'SALVANDO ALTERAÇÕES...'
                            : modoEdicao
                            ? 'SALVAR ALTERAÇÕES'
                            : 'EDITAR INFORMAÇÕES',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),

                  SizedBox(height: ui.cardHeight * 0.10),
                  Container(
                    width: ui.cardWidth,
                    padding: EdgeInsets.symmetric(
                      vertical: ui.cardHeight * 0.05,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 21,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ZONA DE PERIGO',
                              style: GoogleFonts.manrope(
                                fontSize: ui.titleSize * 0.33,
                                fontWeight: FontWeight.w900,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ui.cardHeight * 0.025),
                        Text(
                          'Ao excluir sua conta, seus dados e seu acesso serão removidos permanentemente.',
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.32,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: ui.cardHeight * 0.035),
                        SizedBox(
                          width: ui.cardWidth,
                          height: ui.cardHeight * 0.11,
                          child: OutlinedButton.icon(
                            onPressed: excluindoConta
                                ? null
                                : confirmarExclusaoConta,
                            icon: excluindoConta
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.red,
                                    ),
                                  )
                                : const Icon(
                                    Icons.delete_forever_outlined,
                                    color: Colors.red,
                                  ),
                            label: Text(
                              excluindoConta
                                  ? 'EXCLUINDO CONTA...'
                                  : 'EXCLUIR MINHA CONTA',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                color: Colors.red,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: ui.cardHeight * 0.05),
                  Column(
                    children: [
                      Text(
                        versaoApp.isEmpty
                            ? 'Billhard'
                            : numeroBuild.isEmpty
                            ? 'Billhard v$versaoApp'
                            : 'Billhard v$versaoApp ($numeroBuild)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: ui.titleSize * 0.28,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: ui.cardHeight * 0.008),
                      Text(
                        '© ${DateTime.now().year} Billhard',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: ui.titleSize * 0.25,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secao({
    required BillhardResponsive ui,
    required IconData icone,
    required String titulo,
  }) {
    return Container(
      width: ui.cardWidth,
      padding: EdgeInsets.symmetric(vertical: ui.cardHeight * 0.025),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icone,
            color: BillhardColors.terraCota,
            size: ui.titleSize * 0.6,
          ),
          const SizedBox(width: 6),
          Text(
            titulo,
            style: GoogleFonts.manrope(
              fontSize: ui.titleSize * 0.35,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
