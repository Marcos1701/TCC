import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatador de entrada para valores monetários em Reais (BRL)
/// 
/// Este formatador permite que o usuário digite valores monetários de forma intuitiva:
/// - Aceita apenas números
/// - Formata automaticamente com vírgula para decimais
/// - Permite no máximo 2 casas decimais
/// - Exemplo: usuário digita "12345" e vê "123,45"
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
    // Remove tudo que não é dígito
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limita o número de dígitos
    if (newText.length > maxDigits) {
      newText = newText.substring(0, maxDigits);
    }

    // Se estiver vazio, retorna vazio
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Converte para double (centavos)
    final double value = double.parse(newText) / 100;

    // Formata o valor
    final String formatted = _formatter.format(value).trim();

    // Retorna o novo valor formatado
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Converte o texto formatado de volta para double
  static double parse(String text) {
    if (text.isEmpty) return 0.0;
    
    // Remove formatação e converte
    final cleaned = text.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Formata um valor double para exibição
  static String format(double value) {
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: '',
      decimalDigits: 2,
    );
    return formatter.format(value).trim();
  }
}
