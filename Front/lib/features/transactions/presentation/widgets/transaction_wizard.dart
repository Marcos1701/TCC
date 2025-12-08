import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../categories/presentation/pages/category_form_page.dart';
import 'wizard_components.dart';

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
}

class TransactionWizard extends StatefulWidget {
  const TransactionWizard({super.key});

  @override
  State<TransactionWizard> createState() => _TransactionWizardState();
}

class _TransactionWizardState extends State<TransactionWizard> {
  final _repository = FinanceRepository();
  final _cacheManager = CacheManager();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  
  int _currentStep = 0;
  String _selectedType = 'EXPENSE'; // INCOME ou EXPENSE
  int? _selectedCategoryId;
  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  int _recurrenceValue = 1;
  _RecurrenceUnit _recurrenceUnit = _RecurrenceUnit.months;
  DateTime? _recurrenceEndDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      // Invalidar cache para garantir dados atualizados
      await CacheService.invalidateCategories();
      
      final categories = await _repository.fetchCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _loadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCategories = false);
        FeedbackService.showError(context, 'Erro ao carregar categorias');
      }
    }
  }

  Future<void> _createNewCategory() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CategoryFormPage(
          initialType: _selectedType,
        ),
      ),
    );

    if (result == true) {
      setState(() => _loadingCategories = true);
      await _loadCategories();
      
      if (_filteredCategories.isNotEmpty) {
        setState(() {
          _selectedCategoryId = _filteredCategories.last.id;
        });
      }
    }
  }

  List<CategoryModel> get _filteredCategories {
    return _categories.where((cat) => cat.type == _selectedType).toList();
  }

  bool _canGoNext() {
    switch (_currentStep) {
      case 0:
        return true;
      case 1:
        return _selectedCategoryId != null;
      case 2:
        return _amountController.text.isNotEmpty &&
            (double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0) > 0;
      case 3:
        return true;
      case 4:
        return _descriptionController.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_canGoNext()) {
      if (_currentStep < 4) {
        setState(() => _currentStep++);
      } else {
        _submit();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      
      final transaction = await _repository.createTransaction(
        description: _descriptionController.text.trim(),
        amount: amount,
        type: _selectedType,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        isRecurring: _isRecurring,
        recurrenceValue: _isRecurring ? _recurrenceValue : null,
        recurrenceUnit: _isRecurring ? _recurrenceUnit.backendValue : null,
        recurrenceEndDate: _recurrenceEndDate,
      );

      if (!mounted) return;

      _cacheManager.invalidateAfterTransaction(action: 'transaction created');

      FeedbackService.showTransactionCreated(
        context,
        amount: amount,
        type: _selectedType,
      );

      Navigator.of(context).pop(transaction);
    } catch (e) {
      if (mounted) {
        FeedbackService.showError(
          context,
          'Erro ao criar transação: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Constrain the modal to a maximum of 85% of the screen height
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    Colors.purple.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_card,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nova Transação',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Passo a passo para registrar',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: List.generate(5, (index) {
                      final isActive = index == _currentStep;
                      final isCompleted = index < _currentStep;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(
                            right: index < 4 ? 8 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted || isActive
                                ? AppColors.primary
                                : Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                color: Colors.black,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildStepContent(),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(
                  top: BorderSide(color: Colors.grey[800]!),
                ),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Voltar'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _canGoNext() && !_submitting ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey[800],
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
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentStep == 4 ? 'Concluir' : 'Próximo',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepType();
      case 1:
        return _buildStepCategory();
      case 2:
        return _buildStepAmount();
      case 3:
        return _buildStepRecurrence();
      case 4:
        return _buildStepDescription();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Selecione o tipo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Escolha se é uma receita (dinheiro que entra) ou despesa (dinheiro que sai)',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        TransactionTypeCard(
          icon: Icons.arrow_upward,
          iconColor: AppColors.support,
          title: 'Receita',
          subtitle: 'Dinheiro que entra',
          examples: 'Ex: Salário, Freelance, Vendas',
          isSelected: _selectedType == 'INCOME',
          onTap: () => setState(() => _selectedType = 'INCOME'),
        ),
        const SizedBox(height: 16),
        TransactionTypeCard(
          icon: Icons.arrow_downward,
          iconColor: AppColors.alert,
          title: 'Despesa',
          subtitle: 'Dinheiro que sai',
          examples: 'Ex: Aluguel, Mercado, Transporte',
          isSelected: _selectedType == 'EXPENSE',
          onTap: () => setState(() => _selectedType = 'EXPENSE'),
        ),
      ],
    );
  }

  Widget _buildStepCategory() {
    if (_loadingCategories) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final categories = _filteredCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Escolha a categoria',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecione a categoria para esta ${_selectedType == 'INCOME' ? 'receita' : 'despesa'}',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        if (categories.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: Colors.grey[700],
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma categoria disponível',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crie sua primeira categoria',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _createNewCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Criar Nova Categoria'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...categories.map((category) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TransactionCategoryCard(
                  category: category,
                  isSelected: _selectedCategoryId == category.id,
                  onTap: () => setState(() => _selectedCategoryId = category.id),
                ),
              )),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _createNewCategory,
            icon: const Icon(Icons.add),
            label: const Text('Criar Nova Categoria'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepAmount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. Defina o valor',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quanto foi essa transação?',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    _selectedType == 'INCOME'
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: _selectedType == 'INCOME'
                        ? AppColors.support
                        : AppColors.alert,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0,00',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 32,
                        ),
                        border: InputBorder.none,
                        prefixText: 'R\$ ',
                        prefixStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            QuickAmountButton(
              label: '+ 50',
              onTap: () => _addAmount(50),
            ),
            QuickAmountButton(
              label: '+ 100',
              onTap: () => _addAmount(100),
            ),
            QuickAmountButton(
              label: '+ 500',
              onTap: () => _addAmount(500),
            ),
            QuickAmountButton(
              label: 'Limpar',
              onTap: () => setState(() => _amountController.clear()),
              isDestructive: true,
            ),
          ],
        ),
      ],
    );
  }

  void _addAmount(double value) {
    final current = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final newValue = current + value;
    _amountController.text = newValue.toStringAsFixed(2).replaceAll('.', ',');
    setState(() {});
  }

  Widget _buildStepRecurrence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4. É uma transação recorrente?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Transações recorrentes se repetem automaticamente',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          value: _isRecurring,
          onChanged: (value) => setState(() => _isRecurring = value),
          title: const Text(
            'Tornar recorrente',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _isRecurring ? 'Esta transação se repetirá' : 'Transação única',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          activeColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tileColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[800]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Frequência',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'A cada',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        controller: TextEditingController(
                          text: _recurrenceValue.toString(),
                        ),
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null && parsed > 0) {
                            setState(() => _recurrenceValue = parsed);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<_RecurrenceUnit>(
                        value: _recurrenceUnit,
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Período',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _RecurrenceUnit.values.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(
                              unit == _RecurrenceUnit.days
                                  ? 'Dias'
                                  : unit == _RecurrenceUnit.weeks
                                      ? 'Semanas'
                                      : 'Meses',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _recurrenceUnit = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Resumo: ${_recurrenceUnit.shortLabel(_recurrenceValue)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Data de término (opcional)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _recurrenceEndDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setState(() => _recurrenceEndDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          _recurrenceEndDate == null
                              ? 'Sem data de término'
                              : DateFormat('dd/MM/yyyy').format(_recurrenceEndDate!),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Spacer(),
                        if (_recurrenceEndDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () => setState(() => _recurrenceEndDate = null),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '5. Finalize os detalhes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Adicione uma descrição e confirme a data',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          maxLength: 100,
          decoration: InputDecoration(
            labelText: 'Descrição *',
            labelStyle: const TextStyle(color: Colors.grey),
            hintText: 'Ex: Compra no mercado',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.description, color: Colors.grey),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
                _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
              });
            }
          },
          child: IgnorePointer(
            child: TextField(
              controller: _dateController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Data',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.2),
                Colors.purple.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Resumo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TransactionSummaryRow(
                label: 'Tipo',
                value: _selectedType == 'INCOME' ? 'Receita' : 'Despesa',
                icon: _selectedType == 'INCOME'
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                iconColor: _selectedType == 'INCOME'
                    ? AppColors.support
                    : AppColors.alert,
              ),
              const SizedBox(height: 12),
              TransactionSummaryRow(
                label: 'Categoria',
                value: _categories
                        .firstWhere((c) => c.id == _selectedCategoryId)
                        .name,
                icon: Icons.category,
                iconColor: Colors.blue,
              ),
              const SizedBox(height: 12),
              TransactionSummaryRow(
                label: 'Valor',
                value: _currency.format(
                  double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0,
                ),
                icon: Icons.attach_money,
                iconColor: Colors.green,
              ),
              if (_isRecurring) ...[
                const SizedBox(height: 12),
                TransactionSummaryRow(
                  label: 'Recorrência',
                  value: _recurrenceUnit.shortLabel(_recurrenceValue),
                  icon: Icons.repeat,
                  iconColor: Colors.orange,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
