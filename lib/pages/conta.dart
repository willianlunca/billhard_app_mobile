import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:billhard_app_mobile/pages/login.dart';
import 'package:billhard_app_mobile/services/cep_service.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';
import 'package:billhard_app_mobile/utils/responsive.dart';
import 'package:intl/intl.dart';

class Conta extends StatefulWidget {
  const Conta({super.key});

  @override
  State<Conta> createState() => _ContaState();
}

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.isEmpty) {
      return const TextEditingValue();
    }

    final buffer = StringBuffer();

    for (int i = 0; i < numeros.length && i < 11; i++) {
      if (i == 3 || i == 6) {
        buffer.write('.');
      }

      if (i == 9) {
        buffer.write('-');
      }

      buffer.write(numeros[i]);
    }

    final textoFormatado = buffer.toString();

    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: textoFormatado.length),
    );
  }
}

class NameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final palavras = newValue.text.split(' ');

    final texto = palavras
        .map((palavra) {
          if (palavra.isEmpty) {
            return '';
          }

          return palavra[0].toUpperCase() +
              (palavra.length > 1 ? palavra.substring(1) : '');
        })
        .join(' ');

    return newValue.copyWith(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String valor = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (valor.length > 8) {
      valor = valor.substring(0, 8);
    }

    final String textoFormatado;

    if (valor.length <= 5) {
      textoFormatado = valor;
    } else {
      textoFormatado = '${valor.substring(0, 5)}-${valor.substring(5)}';
    }

    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: textoFormatado.length),
    );
  }
}

class RgInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String valor = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^0-9X]'),
      '',
    );

    if (valor.isEmpty) {
      return const TextEditingValue();
    }

    final possuiX = valor.contains('X');

    if (possuiX) {
      valor = valor.replaceAll('X', '');

      valor = '${valor.substring(0, valor.length.clamp(0, 8))}X';
    } else {
      valor = valor.substring(0, valor.length.clamp(0, 11));
    }

    final String textoFormatado;

    if (valor.length > 9 && !valor.endsWith('X')) {
      textoFormatado = _formatarCin(valor);
    } else {
      textoFormatado = _formatarRgAntigo(valor);
    }

    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: textoFormatado.length),
    );
  }

  String _formatarRgAntigo(String valor) {
    final buffer = StringBuffer();

    for (int i = 0; i < valor.length && i < 9; i++) {
      if (i == 2 || i == 5) {
        buffer.write('.');
      }

      if (i == 8) {
        buffer.write('-');
      }

      buffer.write(valor[i]);
    }

    return buffer.toString();
  }

  String _formatarCin(String valor) {
    final numeros = valor.replaceAll(RegExp(r'[^0-9]'), '');

    final buffer = StringBuffer();

    for (int i = 0; i < numeros.length && i < 11; i++) {
      if (i == 3 || i == 6) {
        buffer.write('.');
      }

      if (i == 9) {
        buffer.write('-');
      }

      buffer.write(numeros[i]);
    }

    return buffer.toString();
  }
}

class _ContaState extends State<Conta> {
  bool modoEdicao = false;
  bool carregandoCidades = false;
  bool buscandoCep = false;
  bool fazendoLogout = false;
  bool excluindoConta = false;
  bool carregandoPerfil = true;
  bool salvandoPerfil = false;

  String? ultimoCepConsultado;

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
    carregarPerfil();
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
    final agora = DateTime.now();

    final anoInicial = dataNascimentoController.text.isNotEmpty
        ? DateFormat('dd/MM/yyyy').parse(dataNascimentoController.text).year
        : agora.year - 30;

    final int? ano = await _selecionarAno(
      anoInicial: anoInicial,
      primeiroAno: 1900,
      ultimoAno: agora.year,
    );

    if (ano == null || !mounted) {
      return;
    }

    final int? mes = await _selecionarMes(ano: ano, mesInicial: 1);

    if (mes == null || !mounted) {
      return;
    }

    final ultimoDiaDoMes = DateTime(ano, mes + 1, 0).day;

    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: DateTime(ano, mes, 1),
      firstDate: DateTime(ano, mes, 1),
      lastDate: DateTime(
        ano,
        mes,
        ano == agora.year && mes == agora.month ? agora.day : ultimoDiaDoMes,
      ),
      locale: const Locale('pt', 'BR'),
      helpText: 'SELECIONE O DIA',
      cancelText: 'CANCELAR',
      confirmText: 'OK',
      builder: _temaCalendarioBillhard,
    );

    if (data != null) {
      dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(data);
    }
  }

  Future<int?> _selecionarAno({
    required int anoInicial,
    required int primeiroAno,
    required int ultimoAno,
  }) {
    return showDialog<int>(
      context: context,
      builder: (context) {
        return Theme(
          data: _temaBillhard(),
          child: AlertDialog(
            backgroundColor: BillhardColors.bege,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Selecione o ano',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: BillhardColors.verdePrincipal,
              ),
            ),
            content: SizedBox(
              width: 320,
              height: 360,
              child: YearPicker(
                firstDate: DateTime(primeiroAno),
                lastDate: DateTime(ultimoAno),
                selectedDate: DateTime(anoInicial),
                currentDate: DateTime.now(),
                onChanged: (data) {
                  Navigator.pop(context, data.year);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<int?> _selecionarMes({required int ano, required int mesInicial}) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    final agora = DateTime.now();

    return showDialog<int>(
      context: context,
      builder: (context) {
        return Theme(
          data: _temaBillhard(),
          child: AlertDialog(
            backgroundColor: BillhardColors.bege,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Selecione o mês de $ano',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: BillhardColors.verdePrincipal,
              ),
            ),
            content: SizedBox(
              width: 320,
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final mes = index + 1;

                  final mesFuturo = ano == agora.year && mes > agora.month;

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: mesFuturo
                        ? null
                        : () {
                            Navigator.pop(context, mes);
                          },
                    child: Ink(
                      decoration: BoxDecoration(
                        color: mes == mesInicial
                            ? BillhardColors.verdePrincipal
                            : BillhardColors.verdePrincipal.withValues(
                                alpha: 0.08,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: BillhardColors.verdePrincipal.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          meses[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: mesFuturo
                                ? Colors.grey
                                : mes == mesInicial
                                ? Colors.white
                                : BillhardColors.verdePrincipal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
    );
  }

  Widget tituloCampo({
    required String titulo,
    required BillhardResponsive ui,
    required double margemTop,
  }) {
    return Container(
      width: ui.cardWidth,
      margin: EdgeInsets.only(top: margemTop),
      child: Row(
        children: [
          Text(
            titulo,
            style: GoogleFonts.manrope(
              fontSize: ui.titleSize * 0.33,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
        ],
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

    return Scaffold(
      backgroundColor: BillhardColors.bege,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: ui.cardHeight * 0.2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: fazendoLogout ? null : confirmarLogout,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  fazendoLogout
                                      ? const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: BillhardColors.terraCota,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.logout_rounded,
                                          size: 19,
                                          color: BillhardColors.terraCota,
                                        ),
                                  const SizedBox(width: 8),
                                  Text(
                                    fazendoLogout ? 'Saindo...' : 'Sair',
                                    style: GoogleFonts.manrope(
                                      fontSize: ui.titleSize * 0.34,
                                      fontWeight: FontWeight.w700,
                                      color: BillhardColors.terraCota,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    //margin: EdgeInsets.only(top: ui.cardHeight * 0.3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: ui.cardWidth * 0.3,
                          height: ui.cardWidth * 0.3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BillhardColors.bege,
                            border: Border.all(
                              color: Colors.grey.shade500,
                              width: 1,
                            ),
                          ),
                          foregroundDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _obterIniciais(nomeController.text),
                                style: TextStyle(
                                  fontSize: ui.titleSize * 0.8,
                                  fontWeight: FontWeight.w700,
                                  color: BillhardColors.verdePrincipal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                nomeController.text.trim().isEmpty
                                    ? 'Usuário Billhard'
                                    : nomeController.text.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: ui.titleSize * 0.65,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                splashColor: BillhardColors.verdePrincipal
                                    .withValues(alpha: 0.20),
                                highlightColor: Colors.transparent,
                                onTap: carregandoPerfil || salvandoPerfil
                                    ? null
                                    : editarOuSalvarPerfil,
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: Center(
                                    child: salvandoPerfil
                                        ? const SizedBox(
                                            width: 17,
                                            height: 17,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: BillhardColors.terraCota,
                                            ),
                                          )
                                        : Icon(
                                            modoEdicao
                                                ? Icons.save_outlined
                                                : Icons.edit_outlined,
                                            color: modoEdicao
                                                ? BillhardColors.verdePrincipal
                                                : BillhardColors.terraCota,
                                            size: 18,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: ui.cardWidth * 0.9,
                          height: ui.cardWidth * 0.1,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey, width: 1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Gerencie suas Informações pessoais',
                              style: GoogleFonts.manrope(
                                fontSize: ui.titleSize * 0.35,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: ui.cardWidth,
                    height: ui.cardHeight * 0.12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          color: BillhardColors.terraCota,
                          size: ui.titleSize * 0.6,
                        ),
                        Container(
                          margin: EdgeInsets.only(left: ui.cardWidth * 0.01),
                          child: Text(
                            'INFORMACOES PESSOAIS',
                            style: GoogleFonts.manrope(
                              fontSize: ui.titleSize * 0.35,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  tituloCampo(
                    titulo: 'NOME COMPLETO',
                    ui: ui,
                    margemTop: ui.cardHeight * 0.02,
                  ),

                  SizedBox(
                    width: ui.cardWidth,
                    child: IgnorePointer(
                      ignoring: !modoEdicao,
                      child: TextFormField(
                        controller: nomeController,
                        readOnly: !modoEdicao,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        textAlignVertical: TextAlignVertical.center,
                        onChanged: (_) {
                          setState(() {});
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-ZÀ-ÿ\s'-]"),
                          ),
                          LengthLimitingTextInputFormatter(60),
                          NameInputFormatter(),
                        ],
                        style: estiloInput,
                        decoration:
                            inputDecoration(
                              hintText: 'Seu nome completo',
                            ).copyWith(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: ui.cardHeight * 0.02,
                              ),
                            ),
                      ),
                    ),
                  ),

                  Container(
                    width: ui.cardWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              width: ui.cardWidth / 2.1,
                              child: tituloCampo(
                                titulo: 'CPF',
                                ui: ui,
                                margemTop: 5,
                              ),
                            ),
                            SizedBox(
                              width: ui.cardWidth / 2.1,
                              child: IgnorePointer(
                                ignoring: !modoEdicao,
                                child: TextFormField(
                                  controller: cpfController,
                                  readOnly: !modoEdicao,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  textAlignVertical: TextAlignVertical.center,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                    CpfInputFormatter(),
                                  ],
                                  style: estiloInput,
                                  decoration:
                                      inputDecoration(
                                        hintText: '000.000.000-00',
                                      ).copyWith(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: ui.cardHeight * 0.02,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            SizedBox(
                              width: ui.cardWidth / 2.1,
                              child: tituloCampo(
                                titulo: 'RG',
                                ui: ui,
                                margemTop: 5,
                              ),
                            ),
                            SizedBox(
                              width: ui.cardWidth / 2.1,
                              child: IgnorePointer(
                                ignoring: !modoEdicao,
                                child: TextFormField(
                                  controller: rgController,
                                  readOnly: !modoEdicao,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  textAlignVertical: TextAlignVertical.center,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                    RgInputFormatter(),
                                  ],
                                  style: estiloInput,
                                  decoration:
                                      inputDecoration(
                                        hintText: '00.000.000-0',
                                      ).copyWith(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: ui.cardHeight * 0.02,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  tituloCampo(
                    titulo: 'TELEFONE',
                    ui: ui,
                    margemTop: ui.cardHeight * 0.02,
                  ),

                  SizedBox(
                    width: ui.cardWidth,
                    child: IgnorePointer(
                      ignoring: !modoEdicao,
                      child: TextFormField(
                        controller: telefoneController,
                        readOnly: !modoEdicao,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        textAlignVertical: TextAlignVertical.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9()+\-\s]'),
                          ),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        style: estiloInput,
                        decoration: inputDecoration(hintText: '(00) 00000-0000')
                            .copyWith(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: ui.cardHeight * 0.02,
                              ),
                            ),
                      ),
                    ),
                  ),

                  Column(
                    children: [
                      tituloCampo(
                        titulo: 'DATA DE NASCIMENTO',
                        ui: ui,
                        margemTop: ui.cardHeight * 0.02,
                      ),
                      SizedBox(
                        width: ui.cardWidth,
                        height: ui.cardHeight * 0.11,
                        child: IgnorePointer(
                          ignoring: !modoEdicao,
                          child: TextFormField(
                            controller: dataNascimentoController,
                            readOnly: true,
                            style: estiloInput,
                            expands: true,
                            minLines: null,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.center,
                            onTap: selecionarDataNascimento,
                            decoration:
                                inputDecoration(
                                  hintText: '00/00/0000',
                                  suffixIcon: const Icon(
                                    Icons.calendar_month_outlined,
                                    color: Colors.grey,
                                  ),
                                ).copyWith(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: ui.cardHeight * 0.02,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  Container(
                    width: ui.cardWidth,
                    height: ui.cardHeight * 0.12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          color: BillhardColors.terraCota,
                          size: ui.titleSize * 0.6,
                        ),
                        Container(
                          margin: EdgeInsets.only(left: ui.cardWidth * 0.01),
                          child: Text(
                            'ENDEREÇO',
                            style: GoogleFonts.manrope(
                              fontSize: ui.titleSize * 0.35,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: ui.cardWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              width: ui.cardWidth / 2.1,
                              child: tituloCampo(
                                titulo: 'CEP',
                                ui: ui,
                                margemTop: 5,
                              ),
                            ),

                            SizedBox(
                              width: ui.cardWidth / 2.1,
                              height: ui.cardHeight * 0.105,
                              child: IgnorePointer(
                                ignoring: !modoEdicao || buscandoCep,
                                child: TextFormField(
                                  controller: cepController,
                                  readOnly: !modoEdicao || buscandoCep,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  textAlignVertical: TextAlignVertical.center,
                                  inputFormatters: [CepInputFormatter()],
                                  style: estiloInput,
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
                                  decoration:
                                      inputDecoration(
                                        hintText: '00000-000',
                                        suffixIcon: buscandoCep
                                            ? const Padding(
                                                padding: EdgeInsets.all(14),
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.search_outlined,
                                                color: Colors.grey,
                                              ),
                                      ).copyWith(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: ui.cardHeight * 0.016,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        Column(
                          children: [
                            SizedBox(
                              width: ui.cardWidth / 2.1,
                              child: tituloCampo(
                                titulo: 'ESTADO',
                                ui: ui,
                                margemTop: ui.cardHeight * 0.02,
                              ),
                            ),
                            SizedBox(
                              width: ui.cardWidth / 2.1,
                              child: IgnorePointer(
                                ignoring: !modoEdicao,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('estado-$estadoSelecionado'),
                                  initialValue: estadoSelecionado,
                                  isExpanded: true,
                                  style: estiloInput,
                                  decoration:
                                      inputDecoration(
                                        hintText: 'Selecione o estado',
                                      ).copyWith(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: ui.cardHeight * 0.016,
                                        ),
                                      ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.grey,
                                  ),
                                  items: estados.map((estado) {
                                    return DropdownMenuItem<String>(
                                      value: estado,
                                      child: Text(estado, style: estiloInput),
                                    );
                                  }).toList(),
                                  onChanged: modoEdicao
                                      ? (novoEstado) {
                                          if (novoEstado == null) {
                                            return;
                                          }

                                          setState(() {
                                            estadoSelecionado = novoEstado;
                                          });

                                          carregarCidades(novoEstado);
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  tituloCampo(
                    titulo: 'CIDADE',
                    ui: ui,
                    margemTop: ui.cardHeight * 0.02,
                  ),

                  SizedBox(
                    width: ui.cardWidth,
                    height: ui.cardHeight * 0.10,
                    child: IgnorePointer(
                      ignoring:
                          !modoEdicao ||
                          estadoSelecionado == null ||
                          carregandoCidades,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'cidade-'
                          '$estadoSelecionado-'
                          '$cidadeSelecionada-'
                          '${cidades.length}',
                        ),

                        initialValue: cidadeSelecionada,

                        isExpanded: true,

                        style: estiloInput,

                        decoration:
                            inputDecoration(
                              hintText: carregandoCidades
                                  ? 'Carregando cidades...'
                                  : estadoSelecionado == null
                                  ? 'Selecione primeiro o estado'
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
                            ).copyWith(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: ui.cardHeight * 0.016,
                              ),
                            ),

                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey,
                        ),

                        /*
       * Controla o texto exibido quando o dropdown
       * estiver fechado.
       */
                        selectedItemBuilder: (BuildContext context) {
                          return cidades.map<Widget>((cidade) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                cidade,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: estiloInput.copyWith(
                                  color: Colors.black,
                                ),
                              ),
                            );
                          }).toList();
                        },

                        items: cidades.map((cidade) {
                          return DropdownMenuItem<String>(
                            value: cidade,
                            child: Text(
                              cidade,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: estiloInput.copyWith(color: Colors.black),
                            ),
                          );
                        }).toList(),

                        onChanged: modoEdicao && !carregandoCidades
                            ? (novaCidade) {
                                setState(() {
                                  cidadeSelecionada = novaCidade;
                                });

                                debugPrint(
                                  'Cidade selecionada: $cidadeSelecionada',
                                );
                              }
                            : null,
                      ),
                    ),
                  ),

                  tituloCampo(
                    titulo: 'ENDEREÇO',
                    ui: ui,
                    margemTop: ui.cardHeight * 0.02,
                  ),

                  SizedBox(
                    width: ui.cardWidth,
                    child: IgnorePointer(
                      ignoring: !modoEdicao,
                      child: TextFormField(
                        controller: enderecoController,
                        readOnly: !modoEdicao,
                        keyboardType: TextInputType.streetAddress,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        textAlignVertical: TextAlignVertical.center,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(120),
                        ],
                        style: estiloInput,
                        decoration: inputDecoration(hintText: 'Rua ou avenida')
                            .copyWith(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: ui.cardHeight * 0.02,
                              ),
                            ),
                      ),
                    ),
                  ),

                  SizedBox(
                    width: ui.cardWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: ui.cardWidth / 2.1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              tituloCampo(
                                titulo: 'NÚMERO',
                                ui: ui,
                                margemTop: ui.cardHeight * 0.02,
                              ),
                              IgnorePointer(
                                ignoring: !modoEdicao,
                                child: TextFormField(
                                  controller: numeroController,
                                  readOnly: !modoEdicao,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  textAlignVertical: TextAlignVertical.center,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  style: estiloInput,
                                  decoration:
                                      inputDecoration(
                                        hintText: 'Digite o número',
                                      ).copyWith(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: ui.cardHeight * 0.02,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: ui.cardWidth / 2.1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              tituloCampo(
                                titulo: 'BAIRRO',
                                ui: ui,
                                margemTop: ui.cardHeight * 0.02,
                              ),
                              IgnorePointer(
                                ignoring: !modoEdicao,
                                child: TextFormField(
                                  controller: bairroController,
                                  readOnly: !modoEdicao,
                                  keyboardType: TextInputType.streetAddress,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  textAlignVertical: TextAlignVertical.center,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(60),
                                  ],
                                  style: estiloInput,
                                  decoration:
                                      inputDecoration(
                                        hintText: 'Nome do bairro',
                                      ).copyWith(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: ui.cardHeight * 0.02,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  tituloCampo(
                    titulo: 'COMPLEMENTO',
                    ui: ui,
                    margemTop: ui.cardHeight * 0.02,
                  ),

                  SizedBox(
                    width: ui.cardWidth,
                    child: IgnorePointer(
                      ignoring: !modoEdicao,
                      child: TextFormField(
                        controller: complementoController,
                        readOnly: !modoEdicao,
                        keyboardType: TextInputType.streetAddress,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        textAlignVertical: TextAlignVertical.center,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(100),
                        ],
                        style: estiloInput,
                        decoration:
                            inputDecoration(
                              hintText:
                                  'Número, apartamento, bloco, sala ou referência',
                            ).copyWith(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: ui.cardHeight * 0.02,
                              ),
                            ),
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
                          width: 1,
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
                            fontWeight: FontWeight.w400,
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
                              side: const BorderSide(
                                color: Colors.red,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: ui.cardHeight * 0.12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
