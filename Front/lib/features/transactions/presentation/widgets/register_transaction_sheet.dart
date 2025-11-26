import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'register_transaction/register_transaction_components.dart';

/// Bottom sheet para registrar nova transação.
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

  final _currencyFormatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

  // Recurrence state
  int? _recurrenceValue;
  RecurrenceUnit? _recurrenceUnit;
  DateTime? _recurrenceEndDate;
  bool _usingCustomRecurrence = false;
  String? _recurrenceError;

  // Theme constants
  static const _sheetColor = Color(0xFF05060A);
  static const _fieldColor = Color(0xFF111522);

  @override
  void initState() {
    super.initState();
    _syncDateLabel();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String get _categoryType => _type;

  void _syncDateLabel() {
    _dateController.text =
        DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate);
  }

  void _setRecurrence(RecurrenceUnit unit, int value, {bool custom = false}) {
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

  Future<void> _openCustomRecurrence() async {
    final result = await showModalBottomSheet<CustomRecurrenceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomRecurrenceSheet(
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
      builder: _datePickerBuilder,
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
      if (focusId != null && result.any((e) => e.id == focusId)) {
        _categoryId = focusId;
      } else if (_categoryId != null &&
          result.any((e) => e.id == _categoryId)) {
        // Keep current selection
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
      builder: _datePickerBuilder,
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      _syncDateLabel();
    }
  }

  Widget _datePickerBuilder(BuildContext context, Widget? child) {
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
      final description = notes.isEmpty ? baseName : '$baseName • $notes';

      final created = await widget.repository.createTransaction(
        type: _type,
        description: description,
        amount: parsedAmount,
        date: _selectedDate,
        categoryId: _categoryId,
        isRecurring: _isRecurring,
        recurrenceValue: _isRecurring ? _recurrenceValue : null,
        recurrenceUnit: _isRecurring ? _recurrenceUnit?.backendValue : null,
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
      builder: (context) => CategoryComposerSheet(
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
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom;
    final dividerColor = Colors.white.withOpacity(0.12);
    final sheetTheme = _buildSheetTheme(context, dividerColor);

    final labelStyle = sheetTheme.textTheme.labelLarge?.copyWith(
      color: Colors.white.withOpacity(0.72),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

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
                  color: _sheetColor,
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
                    _buildHeader(sheetTheme, dividerColor),
                    Divider(color: dividerColor, height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: _buildForm(sheetTheme, labelStyle, dividerColor),
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

  ThemeData _buildSheetTheme(BuildContext context, Color dividerColor) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: _sheetColor,
        onSurface: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: _fieldColor,
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
        hintStyle: base.textTheme.bodyMedium?.copyWith(color: Colors.white54),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(_fieldColor),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
              ? AppColors.primary.withOpacity(0.3)
              : Colors.white24,
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color dividerColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Voltar',
              onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
          ),
          Text(
            'Registrar Transação',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    ThemeData theme,
    TextStyle? labelStyle,
    Color dividerColor,
  ) {
    final inputTextStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white,
    );

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeField(labelStyle, inputTextStyle, dividerColor),
          const SizedBox(height: 20),
          _buildNameField(labelStyle, inputTextStyle),
          const SizedBox(height: 20),
          _buildCategoryField(theme, labelStyle, dividerColor),
          const SizedBox(height: 20),
          _buildAmountAndDateFields(labelStyle, inputTextStyle),
          const SizedBox(height: 20),
          _buildRecurrenceSwitch(theme),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: !_isRecurring
                ? const SizedBox.shrink()
                : RecurrencePanel(
                    key: const ValueKey('recurrence-panel'),
                    recurrenceUnit: _recurrenceUnit,
                    recurrenceValue: _recurrenceValue,
                    recurrenceEndDate: _recurrenceEndDate,
                    usingCustomRecurrence: _usingCustomRecurrence,
                    recurrenceError: _recurrenceError,
                    onPresetSelected: (unit, value) =>
                        _setRecurrence(unit, value),
                    onCustomRecurrence: _openCustomRecurrence,
                    onPickEndDate: _pickRecurrenceEndDate,
                    onClearEndDate: () =>
                        setState(() => _recurrenceEndDate = null),
                    labelStyle: labelStyle,
                  ),
          ),
          if (!_isRecurring) const SizedBox(height: 20),
          _buildNotesField(labelStyle, inputTextStyle),
          const SizedBox(height: 28),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildTypeField(
    TextStyle? labelStyle,
    TextStyle? inputTextStyle,
    Color dividerColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelStyle != null) ...[
          Text('Tipo de Transação', style: labelStyle),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<String>(
          value: _type,
          dropdownColor: _fieldColor,
          style: inputTextStyle,
          iconEnabledColor: Colors.white70,
          borderRadius: BorderRadius.circular(18),
          items: const [
            DropdownMenuItem(value: 'INCOME', child: Text('Receita')),
            DropdownMenuItem(value: 'EXPENSE', child: Text('Despesa')),
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
          'Dica: crie categorias com finalidades como Poupança, '
          'Investimentos ou Renda extra para diferenciar os lançamentos.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
        ),
      ],
    );
  }

  Widget _buildNameField(TextStyle? labelStyle, TextStyle? inputTextStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelStyle != null) ...[
          Text('Nome', style: labelStyle),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          style: inputTextStyle,
          cursorColor: Colors.white,
          decoration: const InputDecoration(hintText: 'Nome da Transação'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Informe um nome.' : null,
        ),
      ],
    );
  }

  Widget _buildCategoryField(
    ThemeData theme,
    TextStyle? labelStyle,
    Color dividerColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelStyle != null) ...[
          Text('Categoria', style: labelStyle),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: _loadingCategories
                  ? _buildCategoryLoading(dividerColor)
                  : _buildCategoryDropdown(theme, dividerColor),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: TextButton.icon(
                onPressed: _handleCreateCategory,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Categoria'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryLoading(Color dividerColor) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dividerColor),
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }

  Widget _buildCategoryDropdown(ThemeData theme, Color dividerColor) {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Sem categoria'),
      ),
      ..._categories.map(
        (category) => DropdownMenuItem<int?>(
          value: category.id,
          child: CategoryMenuItem(category: category),
        ),
      ),
    ];

    return DropdownButtonFormField<int?>(
      value: _categoryId,
      dropdownColor: _fieldColor,
      isExpanded: true,
      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        filled: true,
        fillColor: _fieldColor,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
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
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }
          final category = _categories.firstWhere(
            (e) => e.id == value,
            orElse: () => _categories.first,
          );
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              category.name,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
      onChanged: (value) => setState(() => _categoryId = value),
    );
  }

  Widget _buildAmountAndDateFields(
    TextStyle? labelStyle,
    TextStyle? inputTextStyle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                style: inputTextStyle,
                cursorColor: Colors.white,
                inputFormatters: [
                  CurrencyTextInputFormatter(formatter: _currencyFormatter),
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
                  suffixIcon: Icon(Icons.calendar_today_rounded),
                ),
                onTap: _pickDate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecurrenceSwitch(ThemeData theme) {
    return Row(
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
            if (_recurrenceUnit == null || _recurrenceValue == null) {
              final preset = RecurrencePreset.defaults.first;
              _setRecurrence(preset.unit, preset.value);
            }
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Definir como Recorrente?',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField(TextStyle? labelStyle, TextStyle? inputTextStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelStyle != null) ...[
          Text('Descrição (Opcional)', style: labelStyle),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          style: inputTextStyle,
          cursorColor: Colors.white,
          decoration: const InputDecoration(hintText: 'Descrição da Transação'),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitting ? null : _submit,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
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
            : const Text('Registrar', key: ValueKey('label')),
      ),
    );
  }
}
