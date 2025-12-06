library;

enum RecurrenceUnit {
  days,
  weeks,
  months;

  String get backendValue {
    switch (this) {
      case RecurrenceUnit.days:
        return 'DAYS';
      case RecurrenceUnit.weeks:
        return 'WEEKS';
      case RecurrenceUnit.months:
        return 'MONTHS';
    }
  }

  String shortLabel(int value) {
    switch (this) {
      case RecurrenceUnit.days:
        return value == 1 ? 'Diária' : 'A cada $value dias';
      case RecurrenceUnit.weeks:
        return value == 1 ? 'Semanal' : 'A cada $value semanas';
      case RecurrenceUnit.months:
        return value == 1 ? 'Mensal' : 'A cada $value meses';
    }
  }

  String pickerLabel() {
    switch (this) {
      case RecurrenceUnit.days:
        return 'Dias';
      case RecurrenceUnit.weeks:
        return 'Semanas';
      case RecurrenceUnit.months:
        return 'Meses';
    }
  }
}

class RecurrencePreset {
  const RecurrencePreset({
    required this.value,
    required this.unit,
    required this.title,
    this.subtitle,
  });

  final int value;
  final RecurrenceUnit unit;
  final String title;
  final String? subtitle;

  static const List<RecurrencePreset> defaults = [
    RecurrencePreset(
      value: 1,
      unit: RecurrenceUnit.months,
      title: 'Todo mês',
      subtitle: 'Repete no mesmo dia do lançamento.',
    ),
    RecurrencePreset(
      value: 15,
      unit: RecurrenceUnit.days,
      title: 'A cada 15 dias',
    ),
    RecurrencePreset(
      value: 7,
      unit: RecurrenceUnit.days,
      title: 'A cada 7 dias',
    ),
  ];
}

class CustomRecurrenceResult {
  const CustomRecurrenceResult(this.unit, this.value);

  final RecurrenceUnit unit;
  final int value;
}
