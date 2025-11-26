import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatter para entrada de valores monetários.
///
/// Formata automaticamente a entrada no padrão brasileiro (1.234,56).
class CurrencyTextInputFormatter extends TextInputFormatter {
  CurrencyTextInputFormatter({required this.formatter});

  final NumberFormat formatter;

  /// Cria um formatter com o padrão brasileiro (R$).
  factory CurrencyTextInputFormatter.brazilian() {
    return CurrencyTextInputFormatter(
      formatter: NumberFormat.currency(
        locale: 'pt_BR',
        symbol: '',
        decimalDigits: 2,
      ),
    );
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final value = double.parse(digits) / 100;
    final newText = formatter.format(value).trim();
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
