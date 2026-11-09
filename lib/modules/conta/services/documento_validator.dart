class DocumentoValidator {
  static bool cpfValido(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return false;
    }

    final cpf = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (cpf.length != 11) {
      return false;
    }

    // Bloqueia sequências como 00000000000 e 11111111111.
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
      return false;
    }

    int calcularDigito(String numeros, int pesoInicial) {
      var soma = 0;
      var peso = pesoInicial;

      for (final caractere in numeros.split('')) {
        soma += int.parse(caractere) * peso;
        peso--;
      }

      final resto = soma % 11;

      return resto < 2 ? 0 : 11 - resto;
    }

    final primeiroDigito = calcularDigito(cpf.substring(0, 9), 10);

    final segundoDigito = calcularDigito(
      cpf.substring(0, 9) + primeiroDigito.toString(),
      11,
    );

    return cpf.endsWith('$primeiroDigito$segundoDigito');
  }

  static bool rgFormatoValido(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return false;
    }

    final rg = valor.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');

    // Aceita RG antigo e CIN/CPF.
    if (rg.length < 7 || rg.length > 11) {
      return false;
    }

    // Bloqueia números repetidos.
    if (RegExp(r'^(\d)\1+$').hasMatch(rg)) {
      return false;
    }

    // O X somente pode aparecer no final.
    if (rg.contains('X') && !rg.endsWith('X')) {
      return false;
    }

    // Não permite mais de um X.
    if ('X'.allMatches(rg).length > 1) {
      return false;
    }

    return true;
  }
}
