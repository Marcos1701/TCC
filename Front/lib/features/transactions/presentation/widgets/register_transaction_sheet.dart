import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

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
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _type = 'INCOME';
  int? _categoryId;
  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    final result = await widget.repository.fetchCategories(type: _type);
    if (!mounted) return;
    setState(() {
      _categories = result;
      _categoryId = result.isNotEmpty ? result.first.id : null;
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
            colorScheme: theme.colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      final created = await widget.repository.createTransaction(
        type: _type,
        description: _descriptionController.text.trim(),
        amount: amount,
        date: _selectedDate,
        categoryId: _categoryId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final tokens = theme.extension<AppDecorations>()!;
    final dateLabel = DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: tokens.sheetRadius.topLeft),
          boxShadow: tokens.deepShadow,
          border: Border.all(color: theme.dividerColor),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Registrar transação',
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preencha os dados para acompanhar seu fluxo financeiro.',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'INCOME', child: Text('Receita')),
                      DropdownMenuItem(
                          value: 'EXPENSE', child: Text('Despesa')),
                      DropdownMenuItem(
                          value: 'DEBT_PAYMENT',
                          child: Text('Pagamento de dívida')),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Conte rapidamente sobre a transação.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Valor (ex: 1200.50)',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe o valor.';
                      }
                      return double.tryParse(value.replaceAll(',', '.')) == null
                          ? 'Valor inválido.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data',
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                        suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          dateLabel,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingCategories)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    )
                  else
                    DropdownButtonFormField<int?>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        prefixIcon: Icon(Icons.folder_open_rounded),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sem categoria')),
                        ..._categories.map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _categoryId = value),
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _submitting
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text(
                                'Registrar',
                                key: ValueKey('label'),
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
    );
  }
}
