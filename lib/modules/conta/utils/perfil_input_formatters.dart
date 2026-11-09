import 'package:flutter/services.dart';

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limitado = numeros.substring(0, numeros.length.clamp(0, 11));
    final buffer = StringBuffer();

    for (int i = 0; i < limitado.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(limitado[i]);
    }

    final texto = buffer.toString();

    return TextEditingValue(
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
    var numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    numeros = numeros.substring(0, numeros.length.clamp(0, 8));

    final texto = numeros.length <= 5
        ? numeros
        : '${numeros.substring(0, 5)}-${numeros.substring(5)}';

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class RgInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var valor = newValue.text.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');

    if (valor.contains('X')) {
      valor = valor.replaceAll('X', '');
      valor = '${valor.substring(0, valor.length.clamp(0, 8))}X';
    } else {
      valor = valor.substring(0, valor.length.clamp(0, 11));
    }

    final texto = valor.length > 9 && !valor.endsWith('X')
        ? _formatarCin(valor)
        : _formatarRg(valor);

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  String _formatarRg(String valor) {
    final buffer = StringBuffer();

    for (int i = 0; i < valor.length && i < 9; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('-');
      buffer.write(valor[i]);
    }

    return buffer.toString();
  }

  String _formatarCin(String valor) {
    final buffer = StringBuffer();

    for (int i = 0; i < valor.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(valor[i]);
    }

    return buffer.toString();
  }
}

class NameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = newValue.text
        .split(' ')
        .map((palavra) {
          if (palavra.isEmpty) return '';

          return palavra[0].toUpperCase() +
              (palavra.length > 1 ? palavra.substring(1) : '');
        })
        .join(' ');

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
