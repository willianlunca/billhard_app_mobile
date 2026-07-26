import 'dart:convert';

import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:billhard_app_mobile/pages/login.dart';
import 'package:billhard_app_mobile/pages/modulos.dart';
import 'package:billhard_app_mobile/services/cep_service.dart';
import 'package:billhard_app_mobile/services/documento_validator.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';
import 'package:billhard_app_mobile/utils/perfil_input_formatters.dart';
import 'package:billhard_app_mobile/utils/responsive.dart';
import 'package:billhard_app_mobile/utils/seletor_data_nascimento.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompletarPerfil extends StatefulWidget {
  const CompletarPerfil({super.key});

  @override
  State<CompletarPerfil> createState() => _CompletarPerfilState();
}

class _CompletarPerfilState extends State<CompletarPerfil> {
  final _formKey = GlobalKey<FormState>();

  bool carregandoPerfil = true;
  bool salvandoPerfil = false;
  bool fazendoLogout = false;
  bool buscandoCep = false;
  bool carregandoCidades = false;

  String? ultimoCepConsultado;
  String? estadoSelecionado;
  String? cidadeSelecionada;

  final nomeController = TextEditingController();
  final cpfController = TextEditingController();
  final rgController = TextEditingController();
  final telefoneController = TextEditingController();
  final dataNascimentoController = TextEditingController();
  final cepController = TextEditingController();
  final enderecoController = TextEditingController();
  final numeroController = TextEditingController();
  final bairroController = TextEditingController();
  final complementoController = TextEditingController();

  List<String> cidades = [];

  final List<String> estados = const [
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
    carregarPerfilExistente();
  }

  Future<void> _salvarPaginaAtual() async {
    await PaginaPersistenteService.salvarPagina('CompletarPerfil');
  }

  Future<void> carregarPerfilExistente() async {
    final supabase = Supabase.instance.client;
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      if (mounted) {
        _irParaLogin();
      }
      return;
    }

    try {
      final perfil = await supabase
          .from('perfis')
          .select('''
            nome,
            cpf,
            telefone,
            rg,
            data_nascimento,
            cep,
            estado,
            cidade,
            endereco,
            numero,
            bairro,
            complemento
          ''')
          .eq('id', usuario.id)
          .maybeSingle();

      if (perfil == null) {
        return;
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
      }

      final estado = perfil['estado']?.toString();
      final cidade = perfil['cidade']?.toString();

      if (!mounted) return;

      setState(() {
        estadoSelecionado = estados.contains(estado) ? estado : null;
      });

      if (estadoSelecionado != null) {
        await carregarCidades(estadoSelecionado!, cidadeParaSelecionar: cidade);
      }
    } catch (erro, stackTrace) {
      debugPrint('Erro ao carregar perfil inicial: $erro');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar seus dados.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => carregandoPerfil = false);
      }
    }
  }

  Future<void> salvarPerfil() async {
    if (salvandoPerfil) return;

    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final supabase = Supabase.instance.client;
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      _mostrarMensagem('Sua sessão expirou. Entre novamente.');
      return;
    }

    DateTime? dataNascimento;
    try {
      dataNascimento = DateFormat(
        'dd/MM/yyyy',
      ).parseStrict(dataNascimentoController.text.trim());
    } catch (_) {
      _mostrarMensagem('Informe uma data de nascimento válida.');
      return;
    }

    setState(() => salvandoPerfil = true);

    try {
      final perfisAtualizados = await supabase
          .from('perfis')
          .update({
            'nome': nomeController.text.trim(),
            'cpf': _textoOuNull(cpfController.text),
            'telefone': _textoOuNull(telefoneController.text),
            'rg': _textoOuNull(rgController.text),
            'data_nascimento': DateFormat('yyyy-MM-dd').format(dataNascimento),
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

      await PaginaPersistenteService.salvarPagina('Modulos');

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Modulos()),
        (route) => false,
      );
    } on PostgrestException catch (erro, stackTrace) {
      debugPrint('Erro Supabase ao completar perfil: ${erro.message}');
      debugPrintStack(stackTrace: stackTrace);
      _mostrarMensagem(
        erro.message.isEmpty
            ? 'Não foi possível salvar seus dados.'
            : erro.message,
      );
    } catch (erro, stackTrace) {
      debugPrint('Erro ao completar perfil: $erro');
      debugPrintStack(stackTrace: stackTrace);
      _mostrarMensagem('Não foi possível salvar seus dados.');
    } finally {
      if (mounted) {
        setState(() => salvandoPerfil = false);
      }
    }
  }

  Future<void> fazerLogout() async {
    if (fazendoLogout) return;

    setState(() => fazendoLogout = true);

    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        _irParaLogin();
      }
    } catch (_) {
      _mostrarMensagem('Não foi possível sair da conta.');
    } finally {
      if (mounted) {
        setState(() => fazendoLogout = false);
      }
    }
  }

  void _irParaLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Login()),
      (route) => false,
    );
  }

  Future<void> buscarEnderecoPeloCep() async {
    final cep = cepController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cep.length != 8 || buscandoCep || ultimoCepConsultado == cep) {
      return;
    }

    setState(() => buscandoCep = true);

    try {
      final endereco = await CepService.buscarEndereco(cep);

      if (!mounted) return;

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

      if (!mounted) return;

      setState(() => ultimoCepConsultado = cep);
    } on CepException catch (erro) {
      _mostrarMensagem(erro.mensagem);
    } catch (_) {
      _mostrarMensagem('Não foi possível consultar o CEP.');
    } finally {
      if (mounted) {
        setState(() => buscandoCep = false);
      }
    }
  }

  Future<void> carregarCidades(
    String estado, {
    String? cidadeParaSelecionar,
  }) async {
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

      if (resposta.statusCode != 200) {
        throw Exception('Erro ao carregar cidades');
      }

      final List<dynamic> dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      final novasCidades = dados
          .map((cidade) => cidade['nome'].toString())
          .toList();

      String? cidadeEncontrada;
      if (cidadeParaSelecionar != null && cidadeParaSelecionar.isNotEmpty) {
        final procurada = cidadeParaSelecionar.trim().toLowerCase();
        for (final cidade in novasCidades) {
          if (cidade.trim().toLowerCase() == procurada) {
            cidadeEncontrada = cidade;
            break;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        cidades = novasCidades;
        cidadeSelecionada = cidadeEncontrada;
      });
    } catch (_) {
      _mostrarMensagem('Não foi possível carregar as cidades.');
    } finally {
      if (mounted) {
        setState(() => carregandoCidades = false);
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

  String? _textoOuNull(String texto) {
    final valor = texto.trim();
    return valor.isEmpty ? null : valor;
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      validator: validator,
      style: estilo,
      textAlignVertical: TextAlignVertical.center,
      decoration: inputDecoration(hintText: hint, suffixIcon: suffixIcon),
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    cpfController.dispose();
    rgController.dispose();
    telefoneController.dispose();
    dataNascimentoController.dispose();
    cepController.dispose();
    enderecoController.dispose();
    numeroController.dispose();
    bairroController.dispose();
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
                top: ui.cardHeight * 0.08,
                bottom: ui.cardHeight * 0.12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: ui.cardWidth,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/logo/billhard-versao-1.png',
                          width: ui.cardWidth * 0.45,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return Text(
                              'BILLHARD',
                              style: GoogleFonts.manrope(
                                fontSize: ui.titleSize * 0.85,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: BillhardColors.verdePrincipal,
                              ),
                            );
                          },
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: 'Sair da conta',
                            onPressed: fazendoLogout ? null : fazerLogout,
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
                      ],
                    ),
                  ),
                  SizedBox(height: ui.cardHeight * 0.035),
                  Text(
                    'Complete seu cadastro',
                    style: GoogleFonts.manrope(
                      fontSize: ui.titleSize * 0.65,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: ui.cardHeight * 0.008),
                  Text(
                    'Precisamos de algumas informações antes de continuar.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: ui.titleSize * 0.34,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: ui.cardHeight * 0.06),

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
                    onTap: selecionarDataNascimento,
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
                            DropdownButtonFormField<String>(
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
                          ],
                        ),
                      ),
                    ],
                  ),

                  tituloCampo(titulo: 'CIDADE', ui: ui),
                  DropdownButtonFormField<String>(
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

                  tituloCampo(titulo: 'ENDEREÇO', ui: ui),
                  campoObrigatorio(
                    controller: enderecoController,
                    hint: 'Rua ou avenida',
                    estilo: estiloInput,
                    keyboardType: TextInputType.streetAddress,
                    textCapitalization: TextCapitalization.words,
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
                  ),

                  SizedBox(height: ui.cardHeight * 0.07),
                  SizedBox(
                    width: ui.cardWidth,
                    height: ui.cardHeight * 0.15,
                    child: ElevatedButton(
                      onPressed: salvandoPerfil ? null : salvarPerfil,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BillhardColors.verdePrincipal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: salvandoPerfil
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'SALVAR E CONTINUAR',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
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
