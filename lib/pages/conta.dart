import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:billhard_app_mobile/services/pagina_persistente_service.dart';
import 'package:billhard_app_mobile/utils/responsive.dart';

class Conta extends StatefulWidget {
  const Conta({super.key});

  @override
  State<Conta> createState() => _ContaState();
}

class _ContaState extends State<Conta> {
  bool modoEdicao = false;
  bool carregandoCidades = false;

  final FocusNode senhaFocus = FocusNode();

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController cpfController = TextEditingController();
  final TextEditingController enderecoController = TextEditingController();
  final TextEditingController dataNascimentoController =
      TextEditingController();

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
  }

  Future<void> _salvarPaginaAtual() async {
    await PaginaPersistenteService.salvarPagina('Conta');

    debugPrint('Página Conta salva');
  }

  void alternarModoEdicao() {
    if (modoEdicao) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    setState(() {
      modoEdicao = !modoEdicao;
    });

    debugPrint('Modo edição: $modoEdicao');
  }

  Future<void> carregarCidades(String estado) async {
    setState(() {
      carregandoCidades = true;
      cidadeSelecionada = null;
      cidades = [];
    });

    try {
      final url = Uri.parse(
        'https://servicodados.ibge.gov.br/api/v1/localidades/estados/'
        '$estado/municipios?orderBy=nome',
      );

      final resposta = await http.get(url);

      if (resposta.statusCode != 200) {
        throw Exception('Erro ao carregar cidades');
      }

      final List<dynamic> dados = jsonDecode(resposta.body);

      final novasCidades = dados
          .map((cidade) => cidade['nome'].toString())
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        cidades = novasCidades;
      });
    } catch (erro) {
      debugPrint('Erro ao carregar cidades: $erro');

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
    if (!modoEdicao) {
      return;
    }

    final agora = DateTime.now();

    final dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: agora,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      locale: const Locale('pt', 'BR'),
      helpText: 'DATA DE NASCIMENTO',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    if (dataSelecionada == null) {
      return;
    }

    final dia = dataSelecionada.day.toString().padLeft(2, '0');
    final mes = dataSelecionada.month.toString().padLeft(2, '0');
    final ano = dataSelecionada.year.toString();

    setState(() {
      dataNascimentoController.text = '$dia/$mes/$ano';
    });
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
    double margemSuperior = 0.05,
  }) {
    return Container(
      width: ui.cardWidth,
      margin: EdgeInsets.only(top: ui.cardHeight * margemSuperior),
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
    enderecoController.dispose();
    dataNascimentoController.dispose();

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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: ui.cardHeight * 0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        child: Text(
                          'Willian Lunca',
                          style: GoogleFonts.manrope(
                            fontSize: ui.titleSize * 0.65,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      Container(
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashColor: BillhardColors.verdePrincipal
                                .withValues(alpha: 0.20),
                            highlightColor: Colors.transparent,
                            onTap: alternarModoEdicao,
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: Center(
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: BillhardColors.terraCota,
                                  size: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                tituloCampo(
                  titulo: 'NOME COMPLETO',
                  ui: ui,
                  margemSuperior: 0.1,
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
                      style: estiloInput,
                      decoration: inputDecoration(hintText: 'Willian Lunca'),
                    ),
                  ),
                ),

                tituloCampo(titulo: 'CPF', ui: ui),

                SizedBox(
                  width: ui.cardWidth,
                  child: IgnorePointer(
                    ignoring: !modoEdicao,
                    child: TextFormField(
                      controller: cpfController,
                      readOnly: !modoEdicao,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                        CpfInputFormatter(),
                      ],
                      style: estiloInput,
                      decoration: inputDecoration(hintText: '000.000.000-00'),
                    ),
                  ),
                ),

                tituloCampo(titulo: 'ENDEREÇO', ui: ui),

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
                      style: estiloInput,
                      decoration: inputDecoration(
                        hintText: 'Rua, número e complemento',
                      ),
                    ),
                  ),
                ),

                tituloCampo(titulo: 'ESTADO', ui: ui),

                SizedBox(
                  width: ui.cardWidth,
                  child: IgnorePointer(
                    ignoring: !modoEdicao,
                    child: DropdownButtonFormField<String>(
                      initialValue: estadoSelecionado,
                      isExpanded: true,
                      style: estiloInput,
                      decoration: inputDecoration(
                        hintText: 'Selecione o estado',
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

                tituloCampo(titulo: 'CIDADE', ui: ui),

                SizedBox(
                  width: ui.cardWidth,
                  child: IgnorePointer(
                    ignoring:
                        !modoEdicao ||
                        estadoSelecionado == null ||
                        carregandoCidades,
                    child: DropdownButtonFormField<String>(
                      initialValue: cidadeSelecionada,
                      isExpanded: true,
                      style: estiloInput,
                      decoration: inputDecoration(
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
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                      items: cidades.map((cidade) {
                        return DropdownMenuItem<String>(
                          value: cidade,
                          child: Text(
                            cidade,
                            overflow: TextOverflow.ellipsis,
                            style: estiloInput,
                          ),
                        );
                      }).toList(),
                      onChanged: modoEdicao && !carregandoCidades
                          ? (novaCidade) {
                              setState(() {
                                cidadeSelecionada = novaCidade;
                              });
                            }
                          : null,
                    ),
                  ),
                ),

                tituloCampo(titulo: 'DATA DE NASCIMENTO', ui: ui),

                SizedBox(
                  width: ui.cardWidth,
                  child: IgnorePointer(
                    ignoring: !modoEdicao,
                    child: TextFormField(
                      controller: dataNascimentoController,
                      readOnly: true,
                      style: estiloInput,
                      onTap: selecionarDataNascimento,
                      decoration: inputDecoration(
                        hintText: '00/00/0000',
                        suffixIcon: const Icon(
                          Icons.calendar_month_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: ui.cardHeight * 0.15),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
