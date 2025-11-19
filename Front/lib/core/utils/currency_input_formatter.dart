import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Input formatter for monetary values in Reais (BRL)
/// 
/// This formatter allows the user to type monetary values intuitively:
/// - Accepts only numbers
/// - Automatically formats with comma for decimals
/// - Allows max 2 decimal places
/// - Example: user types "12345" and sees "123,45"
class CurrencyInputFormatter extends TextInputFormatter {
  CurrencyInputFormatter({this.maxDigits = 12});

  final int maxDigits;
  final NumberFormat _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove everything that is not a digit
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit number of digits
    if (newText.length > maxDigits) {
      newText = newText.substring(0, maxDigits);
    }

    // If empty, return empty
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Convert to double (cents)
    final double value = double.parse(newText) / 100;

    // Format value
    final String formatted = _formatter.format(value).trim();

    // Return new formatted value
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Converts formatted text back to double
  static double parse(String text) {
    if (text.isEmpty) return 0.0;
    
    // Remove formatting and convert
    final cleaned = text.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Formats a double value for display
  static String format(double value) {
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: '',
      decimalDigits: 2,
    );
    return formatter.format(value).trim();
  }
}
