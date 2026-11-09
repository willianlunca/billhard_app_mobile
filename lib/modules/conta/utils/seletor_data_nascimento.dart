import 'package:billhard_app_mobile/colors/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SeletorDataNascimento {
  static Future<DateTime?> selecionar({
    required BuildContext context,
    required String dataAtual,
  }) async {
    final agora = DateTime.now();
    final dataInformada = DateFormat('dd/MM/yyyy').tryParse(dataAtual.trim());
    final dataBase = dataInformada ?? DateTime(1995, 1, 1);

    final ano = await _selecionarAno(
      context: context,
      anoInicial: dataBase.year,
      ultimoAno: agora.year,
    );

    if (ano == null || !context.mounted) return null;

    final mesInicial = ano == dataBase.year ? dataBase.month : 1;

    final mes = await _selecionarMes(
      context: context,
      ano: ano,
      mesInicial: mesInicial,
      ultimoMes: ano == agora.year ? agora.month : 12,
    );

    if (mes == null || !context.mounted) return null;

    final ultimoDiaDoMes = DateTime(ano, mes + 1, 0).day;
    final ultimoDiaPermitido = ano == agora.year && mes == agora.month
        ? agora.day
        : ultimoDiaDoMes;

    int diaInicial = 1;

    if (ano == dataBase.year && mes == dataBase.month) {
      diaInicial = dataBase.day.clamp(1, ultimoDiaPermitido);
    }

    return showDatePicker(
      context: context,
      initialDate: DateTime(ano, mes, diaInicial),
      firstDate: DateTime(ano, mes, 1),
      lastDate: DateTime(ano, mes, ultimoDiaPermitido),
      locale: const Locale('pt', 'BR'),
      helpText: 'SELECIONE O DIA',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
      builder: (context, child) {
        return Theme(data: _tema(context), child: child!);
      },
    );
  }

  static Future<int?> _selecionarAno({
    required BuildContext context,
    required int anoInicial,
    required int ultimoAno,
  }) {
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: _tema(dialogContext),
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
              height: 380,
              child: YearPicker(
                firstDate: DateTime(1900),
                lastDate: DateTime(ultimoAno),
                selectedDate: DateTime(anoInicial),
                currentDate: DateTime.now(),
                onChanged: (data) {
                  Navigator.of(dialogContext).pop(data.year);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<int?> _selecionarMes({
    required BuildContext context,
    required int ano,
    required int mesInicial,
    required int ultimoMes,
  }) {
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

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: _tema(dialogContext),
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
                itemCount: ultimoMes,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.55,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final mes = index + 1;
                  final selecionado = mes == mesInicial;

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.of(dialogContext).pop(mes);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: selecionado
                            ? BillhardColors.verdePrincipal
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selecionado
                              ? BillhardColors.verdePrincipal
                              : Colors.grey.shade400,
                        ),
                      ),
                      child: Text(
                        meses[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selecionado
                              ? Colors.white
                              : const Color(0xFF3D403B),
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

  static ThemeData _tema(BuildContext context) {
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
}
