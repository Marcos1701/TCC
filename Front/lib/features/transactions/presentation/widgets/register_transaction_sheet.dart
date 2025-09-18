import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/theme/app_colors.dart';

class RegisterTransactionSheet extends StatefulWidget {
  const RegisterTransactionSheet({super.key, required this.repository});

  final FinanceRepository repository;

  @override
  State<RegisterTransactionSheet> createState() => _RegisterTransactionSheetState();
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onSurface: Colors.white,
                ),
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
    final viewInsets = MediaQuery.of(context).viewInsets;
    final theme = Theme.of(context);
    final dateLabel = DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Registrar transação',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(value: 'INCOME', child: Text('Receita')),
                        DropdownMenuItem(value: 'EXPENSE', child: Text('Despesa')),
                        DropdownMenuItem(value: 'DEBT_PAYMENT', child: Text('Pagamento de dívida')),
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
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Conta pra gente do que se trata.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor (ex: 1200.50)'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Informa o valor.';
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
                          suffixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            dateLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
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
                        value: _categoryId,
                        decoration: const InputDecoration(labelText: 'Categoria'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Sem categoria')),
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
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Registrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
