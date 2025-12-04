import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/interfaces/i_transaction_repository.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_input_formatter.dart';

/// Sheet simples para editar uma transação existente
class EditTransactionSheet extends StatefulWidget {
  const EditTransactionSheet({
    super.key,
    required this.transaction,
    required this.repository,
  });

  final TransactionModel transaction;
  final ITransactionRepository repository;

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _dateController;

  late DateTime _selectedDate;
  late String _type;
  int? _categoryId;
  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.transaction.description);
    _amountController =
        TextEditingController(
          text: CurrencyInputFormatter.format(widget.transaction.amount),
        );
    _dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(widget.transaction.date),
    );
    _selectedDate = widget.transaction.date;
    _type = widget.transaction.type;
    _categoryId = widget.transaction.category?.id;
    _loadCategories();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await widget.repository.fetchCategories(type: _type);
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final amount = CurrencyInputFormatter.parse(_amountController.text);

      await widget.repository.updateTransaction(
        id: widget.transaction.identifier,  // Usar identifier
        type: _type,
        description: _descriptionController.text.trim(),
        amount: amount,
        date: _selectedDate,
        categoryId: _categoryId,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      FeedbackService.showSuccess(
        context,
        'Transação atualizada com sucesso!',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      FeedbackService.showError(
        context,
        'Erro ao atualizar transação. Tente novamente.',
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _onTypeChanged(String? newType) {
    if (newType == null || newType == _type) return;
    setState(() {
      _type = newType;
      _categoryId = null;
      _loadingCategories = true;
    });
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Editar Transação',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
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
                    DropdownMenuItem(value: 'EXPENSE', child: Text('Despesa')),
                  ],
                  onChanged: _onTypeChanged,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe uma descrição';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: 'R\$ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(maxDigits: 12),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe um valor';
                    }
                    final parsed = CurrencyInputFormatter.parse(value);
                    if (parsed <= 0) {
                      return 'Valor inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                if (_loadingCategories)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<int>(
          initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _categoryId = value),
                    validator: (value) {
                      if (value == null) {
                        return 'Selecione uma categoria';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Salvar Alterações',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
