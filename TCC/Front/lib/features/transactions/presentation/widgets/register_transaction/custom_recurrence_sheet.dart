import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'recurrence_models.dart';

class CustomRecurrenceSheet extends StatefulWidget {
  const CustomRecurrenceSheet({
    super.key,
    this.initialValue,
    this.initialUnit,
  });

  final int? initialValue;
  final RecurrenceUnit? initialUnit;

  @override
  State<CustomRecurrenceSheet> createState() => _CustomRecurrenceSheetState();
}

class _CustomRecurrenceSheetState extends State<CustomRecurrenceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late RecurrenceUnit _unit;

  static const _sheetColor = Color(0xFF05060A);
  static const _fieldColor = Color(0xFF111522);

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit ?? RecurrenceUnit.months;
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
    Navigator.of(context).pop(CustomRecurrenceResult(_unit, parsed));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottom = mediaQuery.viewInsets.bottom;
    final outline = Colors.white.withOpacity(0.16);

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
                color: _sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildValueField(),
                      const SizedBox(height: 16),
                      _buildUnitDropdown(),
                      const SizedBox(height: 28),
                      _buildConfirmButton(),
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

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.tune_rounded, color: Colors.white70),
        const SizedBox(width: 12),
        Text(
          'Personalizar recorrência',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildValueField() {
    return TextFormField(
      controller: _valueController,
      keyboardType: const TextInputType.numberWithOptions(
        signed: false,
        decimal: false,
      ),
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: const InputDecoration(
        labelText: 'A cada quantas unidades?',
        hintText: 'Ex.: 2',
        filled: true,
        fillColor: _fieldColor,
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        final parsed = int.tryParse(trimmed);
        if (parsed == null || parsed <= 0) {
          return 'Informe um valor inteiro maior que zero.';
        }
        return null;
      },
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<RecurrenceUnit>(
      value: _unit,
      iconEnabledColor: Colors.white70,
      dropdownColor: _fieldColor,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Unidade',
        filled: true,
        fillColor: _fieldColor,
      ),
      items: RecurrenceUnit.values
          .map(
            (unit) => DropdownMenuItem<RecurrenceUnit>(
              value: unit,
              child: Text(unit.pickerLabel()),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _unit = value);
      },
    );
  }

  Widget _buildConfirmButton() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Aplicar'),
          ),
        ),
      ],
    );
  }
}
