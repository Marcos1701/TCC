import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/category_groups.dart';
import '../../../../core/models/category.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';

enum _RecurrenceUnit { days, weeks, months }

extension _RecurrenceUnitMapper on _RecurrenceUnit {
  String get backendValue {
    switch (this) {
      case _RecurrenceUnit.days:
        return 'DAYS';
      case _RecurrenceUnit.weeks:
        return 'WEEKS';
      case _RecurrenceUnit.months:
        return 'MONTHS';
    }
  }

  String shortLabel(int value) {
    switch (this) {
      case _RecurrenceUnit.days:
        return value == 1 ? 'Diária' : 'A cada $value dias';
      case _RecurrenceUnit.weeks:
        return value == 1 ? 'Semanal' : 'A cada $value semanas';
      case _RecurrenceUnit.months:
        return value == 1 ? 'Mensal' : 'A cada $value meses';
    }
  }

  String pickerLabel() {
    switch (this) {
      case _RecurrenceUnit.days:
        return 'Dias';
      case _RecurrenceUnit.weeks:
        return 'Semanas';
      case _RecurrenceUnit.months:
        return 'Meses';
    }
  }
}

class _RecurrencePreset {
  const _RecurrencePreset({
    required this.value,
    required this.unit,
    required this.title,
    this.subtitle,
  });

  final int value;
  final _RecurrenceUnit unit;
  final String title;
  final String? subtitle;
}

class RegisterTransactionSheet extends StatefulWidget {
  const RegisterTransactionSheet({
    super.key,
    required this.repository,
  });

  final FinanceRepository repository;

  @override
  State<RegisterTransactionSheet> createState() =>
      _RegisterTransactionSheetState();
}

class _RegisterTransactionSheetState extends State<RegisterTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _type = 'INCOME';
  int? _categoryId;
  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;
  bool _submitting = false;
  bool _isRecurring = false;
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);
  int? _recurrenceValue;
  _RecurrenceUnit? _recurrenceUnit;
  DateTime? _recurrenceEndDate;
  bool _usingCustomRecurrence = false;
  String? _recurrenceError;

  static const List<_RecurrencePreset> _presets = [
    _RecurrencePreset(
      value: 1,
      unit: _RecurrenceUnit.months,
      title: 'Todo mês',
      subtitle: 'Repete no mesmo dia do lançamento.',
    ),
    _RecurrencePreset(
      value: 15,
      unit: _RecurrenceUnit.days,
      title: 'A cada 15 dias',
    ),
    _RecurrencePreset(
      value: 7,
      unit: _RecurrenceUnit.days,
      title: 'A cada 7 dias',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _syncDateLabel();
    _loadCategories();
  }

  String get _categoryType => _type == 'DEBT_PAYMENT' ? 'DEBT' : _type;

  void _syncDateLabel() {
    _dateController.text =
        DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate);
  }

  void _setRecurrence(_RecurrenceUnit unit, int value,
      {bool custom = false}) {
    setState(() {
      _recurrenceUnit = unit;
      _recurrenceValue = value;
      _usingCustomRecurrence = custom;
      _recurrenceError = null;
    });
  }

  void _clearRecurrence() {
    setState(() {
      _recurrenceUnit = null;
      _recurrenceValue = null;
      _recurrenceEndDate = null;
      _usingCustomRecurrence = false;
      _recurrenceError = null;
    });
  }

  String? get _recurrenceSummary {
    if (!_isRecurring || _recurrenceUnit == null || _recurrenceValue == null) {
      return null;
    }
    final unit = _recurrenceUnit!;
    final value = _recurrenceValue!;
    final base = unit.shortLabel(value);
    if (_recurrenceEndDate != null) {
      final formatted =
          DateFormat('dd/MM/yyyy', 'pt_BR').format(_recurrenceEndDate!);
      return '$base até $formatted';
    }
    return base;
  }

  Future<void> _openCustomRecurrence() async {
    final result = await showModalBottomSheet<_CustomRecurrenceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomRecurrenceSheet(
        initialValue: _recurrenceValue,
        initialUnit: _recurrenceUnit,
      ),
    );
    if (result == null) return;
    _setRecurrence(result.unit, result.value, custom: true);
  }

  Future<void> _pickRecurrenceEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.primary,
              surface: const Color(0xFF10121D),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _recurrenceEndDate = picked);
  }

  Future<void> _loadCategories({int? focusId}) async {
    setState(() => _loadingCategories = true);
    final result =
        await widget.repository.fetchCategories(type: _categoryType);
    if (!mounted) return;
    setState(() {
      _categories = result;
      if (focusId != null && result.any((element) => element.id == focusId)) {
        _categoryId = focusId;
      } else if (_categoryId != null &&
          result.any((element) => element.id == _categoryId)) {
      } else {
        _categoryId = result.isNotEmpty ? result.first.id : null;
      }
      _loadingCategories = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.primary,
              surface: const Color(0xFF10121D),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      _syncDateLabel();
    }
  }

  double? _parseAmount(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (sanitized.isEmpty) return null;
    final normalized = sanitized.contains(',')
        ? sanitized.replaceAll('.', '').replaceAll(',', '.')
        : sanitized;
    return double.tryParse(normalized);
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o valor.';
    }
    final parsed = _parseAmount(value);
    if (parsed == null) {
      return 'Valor inválido.';
    }
    if (parsed <= 0) {
      return 'Informe um valor maior que zero.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isRecurring && (_recurrenceValue == null || _recurrenceUnit == null)) {
      setState(() {
        _recurrenceError = 'Selecione como a transação deve se repetir.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final parsedAmount = _parseAmount(_amountController.text);
      if (parsedAmount == null) {
        throw const FormatException('invalid amount');
      }

      final baseName = _nameController.text.trim();
      final notes = _notesController.text.trim();
      final description =
          notes.isEmpty ? baseName : '$baseName • $notes';

      final created = await widget.repository.createTransaction(
        type: _type,
        description: description,
        amount: parsedAmount,
        date: _selectedDate,
        categoryId: _categoryId,
        isRecurring: _isRecurring,
        recurrenceValue: _isRecurring ? _recurrenceValue : null,
        recurrenceUnit:
            _isRecurring ? _recurrenceUnit?.backendValue : null,
        recurrenceEndDate: _isRecurring ? _recurrenceEndDate : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (_) {
      if (!mounted) return;
      FeedbackService.showError(
        context,
        'Não foi possível registrar a transação. Tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleCreateCategory() async {
    FocusScope.of(context).unfocus();
    final created = await showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryComposerSheet(
        repository: widget.repository,
        initialType: _categoryType,
        existingNames: _categories.map((e) => e.name.toLowerCase()).toSet(),
      ),
    );

    if (created == null || !mounted) return;
    await _loadCategories(focusId: created.id);
    if (!mounted) return;
    FeedbackService.showSuccess(
      context,
      'Categoria "${created.name}" criada com sucesso!',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom;
    const sheetColor = Color(0xFF05060A);
    const fieldColor = Color(0xFF111522);
    final dividerColor = Colors.white.withValues(alpha: 0.12);

    final base = Theme.of(context);
    final sheetTheme = base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: sheetColor,
        onSurface: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: fieldColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.alert),
        ),
        prefixIconColor: Colors.white54,
        suffixIconColor: Colors.white54,
        hintStyle: base.textTheme.bodyMedium?.copyWith(
          color: Colors.white54,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(fieldColor),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          side: WidgetStateProperty.all(BorderSide(color: dividerColor)),
        ),
      ),
      iconTheme: base.iconTheme.copyWith(color: Colors.white70),
      dividerColor: dividerColor,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.white24,
        ),
      ),
    );

    final labelStyle = sheetTheme.textTheme.labelLarge?.copyWith(
      color: Colors.white.withValues(alpha: 0.72),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    final inputTextStyle =
        sheetTheme.textTheme.bodyMedium?.copyWith(color: Colors.white);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.92,
            minHeight: mediaQuery.size.height * 0.7,
          ),
          child: Material(
            color: Colors.transparent,
            child: Theme(
              data: sheetTheme,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(36)),
                  border: Border.all(color: dividerColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 32,
                      offset: Offset(0, -12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: 'Voltar',
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded),
                            ),
                          ),
                          Text(
                            'Registrar Transação',
                            style: sheetTheme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: dividerColor, height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Form(
                          key: _formKey,
                          autovalidateMode:
                              AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (labelStyle != null) ...[
                                Text('Tipo de Transação', style: labelStyle),
                                const SizedBox(height: 8),
                              ],
                              DropdownButtonFormField<String>(
                                key: ValueKey(_type),
                                initialValue: _type,
                                dropdownColor: fieldColor,
                                style: inputTextStyle,
                                iconEnabledColor: Colors.white70,
                                borderRadius: BorderRadius.circular(18),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'INCOME',
                                    child: Text('Receita'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'EXPENSE',
                                    child: Text('Despesa'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _type = value;
                                    _categoryId = null;
                                  });
                                  _loadCategories();
                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Dica: crie categorias com finalidades como Poupança, Investimentos ou Renda extra para diferenciar os lançamentos.',
                                style: sheetTheme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (labelStyle != null) ...[
                                Text('Nome', style: labelStyle),
                                const SizedBox(height: 8),
                              ],
                              TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                style: inputTextStyle,
                                cursorColor: Colors.white,
                                decoration: const InputDecoration(
                                  hintText: 'Nome da Transação',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Informe um nome.'
                                        : null,
                              ),
                              const SizedBox(height: 20),
                              if (labelStyle != null) ...[
                                Text('Categoria', style: labelStyle),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: _loadingCategories
                                        ? Container(
                                            height: 56,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: fieldColor,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: dividerColor,
                                              ),
                                            ),
                                            child: const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                              ),
                                            ),
                                          )
                                        : () {
                                            final items = <DropdownMenuItem<int?>>[
                                              const DropdownMenuItem<int?>(
                                                value: null,
                                                child: Text('Sem categoria'),
                                              ),
                                              ..._categories.map(
                                                (category) => DropdownMenuItem<int?>(
                                                  value: category.id,
                                                  child: _CategoryMenuItem(
                                                    category: category,
                                                  ),
                                                ),
                                              ),
                                            ];
                                            return DropdownButtonFormField<int?>(
                                              key: ValueKey(_categoryId ?? -1),
                                              initialValue: _categoryId,
                                              dropdownColor: fieldColor,
                                              isExpanded: true,
                                              style: sheetTheme.textTheme.bodyMedium
                                                  ?.copyWith(color: Colors.white),
                                              decoration: InputDecoration(
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 18,
                                                  vertical: 16,
                                                ),
                                                filled: true,
                                                fillColor: fieldColor,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                  borderSide: BorderSide(
                                                    color: dividerColor,
                                                  ),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                  borderSide: BorderSide(
                                                    color: dividerColor,
                                                  ),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                  borderSide: const BorderSide(
                                                    color: AppColors.primary,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              iconEnabledColor: Colors.white70,
                                              items: items,
                                              selectedItemBuilder: (context) {
                                                return items.map((item) {
                                                  final value = item.value;
                                                  if (value == null) {
                                                    return Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        'Sem categoria',
                                                        style: sheetTheme
                                                            .textTheme.bodyMedium
                                                            ?.copyWith(
                                                              color: Colors.white,
                                                            ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    );
                                                  }
                                                  CategoryModel? category;
                                                  for (final element in _categories) {
                                                    if (element.id == value) {
                                                      category = element;
                                                      break;
                                                    }
                                                  }
                                                  return Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      category?.name ?? 'Categoria',
                                                      style: sheetTheme
                                                          .textTheme.bodyMedium
                                                          ?.copyWith(
                                                            color: Colors.white,
                                                          ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList();
                                              },
                                              onChanged: (value) =>
                                                  setState(() => _categoryId = value),
                                            );
                                          }(),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    height: 56,
                                    child: TextButton.icon(
                                      onPressed: _handleCreateCategory,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Categoria'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        backgroundColor:
                                            AppColors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        foregroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (labelStyle != null) ...[
                                Text('Valores e Data', style: labelStyle),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _amountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      textInputAction: TextInputAction.next,
                                      style: inputTextStyle,
                                      cursorColor: Colors.white,
                                      inputFormatters: [
                                        _CurrencyTextInputFormatter(
                                          formatter: _currencyFormatter,
                                        ),
                                      ],
                                      decoration: const InputDecoration(
                                        hintText: '0,00',
                                        prefixText: 'R\$ ',
                                      ),
                                      validator: _validateAmount,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _dateController,
                                      readOnly: true,
                                      style: inputTextStyle,
                                      cursorColor: Colors.white,
                                      decoration: const InputDecoration(
                                        hintText: '00/00/0000',
                                        suffixIcon:
                                            Icon(Icons.calendar_today_rounded),
                                      ),
                                      onTap: _pickDate,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Switch(
                                    value: _isRecurring,
                                    onChanged: (value) {
                                      if (!value) {
                                        setState(() => _isRecurring = false);
                                        _clearRecurrence();
                                        return;
                                      }
                                      setState(() => _isRecurring = true);
                                      if (_recurrenceUnit == null ||
                                          _recurrenceValue == null) {
                                        final preset = _presets.first;
                                        _setRecurrence(
                                          preset.unit,
                                          preset.value,
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Definir como Recorrente?',
                                      style: sheetTheme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: !_isRecurring
                                    ? const SizedBox.shrink()
                                    : Column(
                                        key:
                                            const ValueKey('recurrence-panel'),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 12),
                                          if (labelStyle != null)
                                            Text(
                                              'Com que frequência repetir?',
                                              style: labelStyle,
                                            ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: [
                                              for (final preset in _presets)
                                                _RecurrenceOptionChip(
                                                  title: preset.title,
                                                  subtitle: preset.subtitle,
                                                  selected:
                                                      !_usingCustomRecurrence &&
                                                          _recurrenceUnit ==
                                                              preset.unit &&
                                                          _recurrenceValue ==
                                                              preset.value,
                                                  onTap: () => _setRecurrence(
                                                    preset.unit,
                                                    preset.value,
                                                    custom: false,
                                                  ),
                                                ),
                                              _RecurrenceOptionChip(
                                                title: 'Personalizar...',
                                                subtitle:
                                                    'Informe valor e unidade.',
                                                selected: _usingCustomRecurrence,
                                                onTap: _openCustomRecurrence,
                                                isOutlined: true,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _RecurrenceSummaryCard(
                                            summary: _recurrenceSummary ??
                                                'Escolha uma frequência para repetir automaticamente.',
                                            onEdit: _openCustomRecurrence,
                                            hasSelection: _recurrenceSummary !=
                                                null,
                                          ),
                                          if (_recurrenceError != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              _recurrenceError!,
                                              style: sheetTheme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                color: AppColors.alert,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          _RecurrenceEndDatePicker(
                                            date: _recurrenceEndDate,
                                            onPick: _pickRecurrenceEndDate,
                                            onClear: () => setState(
                                              () => _recurrenceEndDate = null,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                              ),
                              if (!_isRecurring) const SizedBox(height: 20),
                              if (labelStyle != null) ...[
                                Text('Descrição (Opcional)',
                                    style: labelStyle),
                                const SizedBox(height: 8),
                              ],
                              TextFormField(
                                controller: _notesController,
                                maxLines: 4,
                                textInputAction: TextInputAction.done,
                                style: inputTextStyle,
                                cursorColor: Colors.white,
                                decoration: const InputDecoration(
                                  hintText: 'Descrição da Transação',
                                ),
                              ),
                              const SizedBox(height: 28),
                              ElevatedButton(
                                onPressed: _submitting ? null : _submit,
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 220),
                                  child: _submitting
                                      ? const SizedBox(
                                          key: ValueKey('loading'),
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Registrar',
                                          key: ValueKey('label'),
                                        ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _CategoryComposerSheet extends StatefulWidget {
  const _CategoryComposerSheet({
    required this.repository,
    required this.initialType,
    required this.existingNames,
  });

  final FinanceRepository repository;
  final String initialType;
  final Set<String> existingNames;

  @override
  State<_CategoryComposerSheet> createState() => _CategoryComposerSheetState();
}

class _CategoryComposerSheetState extends State<_CategoryComposerSheet> {
  static const List<Color> _swatches = [
    AppColors.primary,
    Color(0xFF0A62D1),
    AppColors.highlight,
    Color(0xFFFFC94D),
    Color(0xFF3DD598),
    Color(0xFF6C5CE7),
    Color(0xFFEF6F6C),
    Color(0xFF1ABCFE),
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late String _type;
  late String _group;
  Color _selectedColor = _swatches.first;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _group = _defaultGroupForType(_type);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _defaultGroupForType(String type) {
    final options = CategoryGroupMetadata.groupsForType(type);
    return options.first;
  }

  void _updateType(String value) {
    if (_type == value) return;
    setState(() {
      _type = value;
      final options = CategoryGroupMetadata.groupsForType(_type);
      if (!options.contains(_group)) {
        _group = options.first;
      }
    });
  }

  void _updateGroup(String value) {
    setState(() => _group = value);
  }

  void _updateColor(Color color) {
    setState(() => _selectedColor = color);
  }

  String? _validateName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Informe um nome.';
    }
    if (widget.existingNames.contains(trimmed.toLowerCase())) {
      return 'Você já tem uma categoria com esse nome.';
    }
    return null;
  }

  String _colorToHex(Color color) {
    final value =
        color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.substring(2)}';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final created = await widget.repository.createCategory(
        name: _nameController.text.trim(),
        type: _type,
        color: _colorToHex(_selectedColor),
        group: _group,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível salvar a categoria. Tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom;
    const sheetColor = Color(0xFF05060A);
    const fieldColor = Color(0xFF111522);
    final outline = Colors.white.withValues(alpha: 0.12);
    final theme = Theme.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.82,
            minHeight: mediaQuery.size.height * 0.55,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: outline),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 36,
                    offset: Offset(0, -12),
                  ),
                ],
              ),
              child: Theme(
                data: theme.copyWith(
                  colorScheme: theme.colorScheme.copyWith(
                    surface: sheetColor,
                    onSurface: Colors.white,
                    primary: AppColors.primary,
                  ),
                  inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                    filled: true,
                    fillColor: fieldColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.4),
                    ),
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white70),
                            onPressed: _submitting
                                ? null
                                : () => Navigator.of(context).maybePop(),
                          ),
                          Expanded(
                            child: Text(
                              'Nova categoria',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Divider(color: outline, height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Form(
                          key: _formKey,
                          autovalidateMode:
                              AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tipo de categoria',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  _CategoryChip(
                                    label: 'Receita',
                                    selected: _type == 'INCOME',
                                    onTap: () => _updateType('INCOME'),
                                  ),
                                  _CategoryChip(
                                    label: 'Despesa',
                                    selected: _type == 'EXPENSE',
                                    onTap: () => _updateType('EXPENSE'),
                                  ),
                                  _CategoryChip(
                                    label: 'Dívida',
                                    selected: _type == 'DEBT',
                                    onTap: () => _updateType('DEBT'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Nome',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                validator: _validateName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.white),
                                cursorColor: Colors.white,
                                decoration: const InputDecoration(
                                  hintText: 'Ex.: Poupança Nubank',
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Finalidade',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: CategoryGroupMetadata
                                    .groupsForType(_type)
                                    .map((value) {
                                  return _CategoryChip(
                                    label: CategoryGroupMetadata.labels[value] ??
                                        value,
                                    selected: _group == value,
                                    onTap: () => _updateGroup(value),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Cor',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _swatches.map((color) {
                                  final isSelected = color == _selectedColor;
                                  return GestureDetector(
                                    onTap: () => _updateColor(color),
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : color.withValues(alpha: 0.6),
                                          width: isSelected ? 3 : 2,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withValues(alpha: 0.5),
                                                  blurRadius: 12,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 20),
                                Text(
                                  _error!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.alert,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              ElevatedButton(
                                onPressed: _submitting ? null : _submit,
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  child: _submitting
                                      ? const SizedBox(
                                          key: ValueKey('category-loading'),
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Salvar categoria',
                                          key: ValueKey('category-label'),
                                        ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
      backgroundColor: const Color(0xFF1A1F2D),
      selectedColor: AppColors.primary,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _CategoryMenuItem extends StatelessWidget {
  const _CategoryMenuItem({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupLabel = category.group != null
        ? CategoryGroupMetadata.labels[category.group!] ?? category.group!
        : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bookmark_border_rounded, size: 18, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (groupLabel != null)
                    Text(
                      groupLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurrenceOptionChip extends StatelessWidget {
  const _RecurrenceOptionChip({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.isOutlined = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool isOutlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = selected
        ? AppColors.primary.withValues(alpha: 0.16)
        : const Color(0xFF0B1020);
    final borderColor = selected
        ? AppColors.primary
        : (isOutlined
            ? Colors.white.withValues(alpha: 0.24)
            : Colors.white.withValues(alpha: 0.12));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurrenceSummaryCard extends StatelessWidget {
  const _RecurrenceSummaryCard({
    required this.summary,
    required this.onEdit,
    required this.hasSelection,
  });

  final String summary;
  final VoidCallback onEdit;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.repeat_rounded,
                color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight:
                        hasSelection ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (!hasSelection) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Escolha uma opção ou personalize para que o lançamento se repita automaticamente.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }
}

class _RecurrenceEndDatePicker extends StatelessWidget {
  const _RecurrenceEndDatePicker({
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? 'Sem data final (continua até você remover)'
        : 'Até ${DateFormat('dd/MM/yyyy', 'pt_BR').format(date!)}';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.event_repeat_rounded),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
            color: Colors.white60,
            tooltip: 'Remover data final',
          ),
        ],
      ],
    );
  }
}

class _CustomRecurrenceResult {
  const _CustomRecurrenceResult(this.unit, this.value);

  final _RecurrenceUnit unit;
  final int value;
}

class _CustomRecurrenceSheet extends StatefulWidget {
  const _CustomRecurrenceSheet({
    this.initialValue,
    this.initialUnit,
  });

  final int? initialValue;
  final _RecurrenceUnit? initialUnit;

  @override
  State<_CustomRecurrenceSheet> createState() =>
      _CustomRecurrenceSheetState();
}

class _CustomRecurrenceSheetState extends State<_CustomRecurrenceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late _RecurrenceUnit _unit;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit ?? _RecurrenceUnit.months;
    final value = widget.initialValue != null && widget.initialValue! > 0
        ? widget.initialValue!
        : 1;
    _valueController = TextEditingController(text: value.toString());
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final parsed = int.tryParse(_valueController.text.trim());
    if (parsed == null || parsed <= 0) return;
    Navigator.of(context).pop(_CustomRecurrenceResult(_unit, parsed));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottom = mediaQuery.viewInsets.bottom;
    const sheetColor = Color(0xFF05060A);
    const fieldColor = Color(0xFF111522);
    final outline = Colors.white.withValues(alpha: 0.16);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.65,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: outline),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 32,
                    offset: Offset(0, -12),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded,
                              color: Colors.white70),
                          const SizedBox(width: 12),
                          Text(
                            'Personalizar recorrência',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _valueController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          labelText: 'A cada quantas unidades?',
                          hintText: 'Ex.: 2',
                          filled: true,
                          fillColor: fieldColor,
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          final parsed = int.tryParse(trimmed);
                          if (parsed == null || parsed <= 0) {
                            return 'Informe um valor inteiro maior que zero.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<_RecurrenceUnit>(
                        initialValue: _unit,
                        iconEnabledColor: Colors.white70,
                        dropdownColor: fieldColor,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Unidade',
                          filled: true,
                          fillColor: fieldColor,
                        ),
                        items: _RecurrenceUnit.values
                            .map(
                              (unit) => DropdownMenuItem<_RecurrenceUnit>(
                                value: unit,
                                child: Text(unit.pickerLabel()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _unit = value);
                        },
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _confirm,
                              child: const Text('Aplicar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyTextInputFormatter extends TextInputFormatter {
  _CurrencyTextInputFormatter({required this.formatter});

  final NumberFormat formatter;

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
