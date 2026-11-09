import 'dart:convert';

import 'package:http/http.dart' as http;

class EnderecoCep {
  final String cep;
  final String logradouro;
  final String complemento;
  final String bairro;
  final String cidade;
  final String uf;
  final String estado;
  final String ibge;
  final String ddd;

  const EnderecoCep({
    required this.cep,
    required this.logradouro,
    required this.complemento,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.estado,
    required this.ibge,
    required this.ddd,
  });

  factory EnderecoCep.fromJson(Map<String, dynamic> json) {
    return EnderecoCep(
      cep: json['cep']?.toString() ?? '',
      logradouro: json['logradouro']?.toString() ?? '',
      complemento: json['complemento']?.toString() ?? '',
      bairro: json['bairro']?.toString() ?? '',
      cidade: json['localidade']?.toString() ?? '',
      uf: json['uf']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      ibge: json['ibge']?.toString() ?? '',
      ddd: json['ddd']?.toString() ?? '',
    );
  }
}

class CepService {
  static Future<EnderecoCep> buscarEndereco(String cepInformado) async {
    final cep = cepInformado.replaceAll(RegExp(r'[^0-9]'), '');

    if (cep.length != 8) {
      throw const CepException('O CEP deve possuir 8 números.');
    }

    final url = Uri.https('viacep.com.br', '/ws/$cep/json/');

    try {
      final resposta = await http.get(url).timeout(const Duration(seconds: 10));

      if (resposta.statusCode != 200) {
        throw const CepException('Não foi possível consultar o CEP.');
      }

      final dynamic respostaJson = jsonDecode(utf8.decode(resposta.bodyBytes));

      if (respostaJson is! Map<String, dynamic>) {
        throw const CepException('O serviço retornou uma resposta inválida.');
      }

      if (respostaJson['erro'] == true) {
        throw const CepException('CEP não encontrado.');
      }

      return EnderecoCep.fromJson(respostaJson);
    } on CepException {
      rethrow;
    } on http.ClientException {
      throw const CepException('Não foi possível conectar ao serviço de CEP.');
    } on FormatException {
      throw const CepException('O serviço retornou dados inválidos.');
    } catch (_) {
      throw const CepException('Ocorreu um erro ao consultar o CEP.');
    }
  }
}

class CepException implements Exception {
  final String mensagem;

  const CepException(this.mensagem);

  @override
  String toString() {
    return mensagem;
  }
}
