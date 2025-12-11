import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String cleanedText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanedText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final double value = double.parse(cleanedText) / 100;

    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: '',
      decimalDigits: 2,
    );
    final String formatted = formatter.format(value).trim();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class InitialSetupPage extends StatefulWidget {
  const InitialSetupPage({
    super.key,
    this.onComplete,
  });

  final VoidCallback? onComplete;

  @override
  State<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends State<InitialSetupPage> {
  final _repository = FinanceRepository();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isSubmitting = false;

  final List<_EssentialTransaction> _transactions = [];
  
  List<CategoryModel> _incomeCategories = [];
  List<CategoryModel> _expenseCategories = [];
  bool _loadingCategories = true;

  int _nextKey = 0;

  /// Converts a hex color string to Color, with fallback
  Color _getCategoryColor(CategoryModel? category, Color fallback) {
    if (category == null || category.color == null) return fallback;
    try {
      final hexColor = category.color!.replaceFirst('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (_) {
      return fallback;
    }
  }


  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeDefaultTransactions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final t in _transactions) {
      t.amountController.dispose();
      t.descriptionController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final income = await _repository.fetchCategories(type: 'INCOME');
      final expense = await _repository.fetchCategories(type: 'EXPENSE');
      
      if (!mounted) return;
      
      setState(() {
        _incomeCategories = income;
        _expenseCategories = expense;
        _loadingCategories = false;
      });
      
      _updateDefaultCategories();
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _loadingCategories = false);
      
      FeedbackService.showError(
        context,
        'Erro ao carregar categorias. Tente novamente.',
      );
    }
  }

  void _initializeDefaultTransactions() {
    // Receitas (INCOME)
    _transactions.addAll([
      _EssentialTransaction(
        key: _nextKey++,
        description: 'Salário',
        type: 'INCOME',
        amountController: TextEditingController(),
        descriptionController: TextEditingController(text: 'Salário'),
        icon: Icons.account_balance_wallet_rounded,
        hint: 'Ex: 3500,00',
        group: 'REGULAR_INCOME',
        isDefault: true,
      ),
      _EssentialTransaction(
        key: _nextKey++,
        description: 'Freelance / Renda Extra',
        type: 'INCOME',
        amountController: TextEditingController(),
        descriptionController: TextEditingController(text: 'Freelance / Renda Extra'),
        icon: Icons.work_rounded,
        hint: 'Ex: 500,00',
        group: 'EXTRA_INCOME',
        isDefault: true,
      ),
    ]);

    // Aportes (EXPENSE com categoria SAVINGS/INVESTMENT)
    _transactions.addAll([
      _EssentialTransaction(
        key: _nextKey++,
        description: 'Investimentos',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        descriptionController: TextEditingController(text: 'Investimentos'),
        icon: Icons.trending_up_rounded,
        hint: 'Ex: 500,00',
        group: 'INVESTMENT',
        isAporte: true,
        isDefault: true,
      ),
      _EssentialTransaction(
        key: _nextKey++,
        description: 'Reserva de Emergência',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        descriptionController: TextEditingController(text: 'Reserva de Emergência'),
        icon: Icons.savings_rounded,
        hint: 'Ex: 1000,00',
        group: 'SAVINGS',
        isAporte: true,
        isDefault: true,
      ),
      _EssentialTransaction(
        key: _nextKey++,
        description: 'Poupança',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        descriptionController: TextEditingController(text: 'Poupança'),
        icon: Icons.account_balance_rounded,
        hint: 'Ex: 300,00',
        group: 'SAVINGS',
        isAporte: true,
        isDefault: true,
      ),
    ]);

    // Despesas regulares
    _transactions.addAll([
      _EssentialTransaction(
        key: _nextKey++,
        description: 'Alimentação',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        descriptionController: TextEditingController(text: 'Alimentação'),
        icon: Icons.restaurant_rounded,
        hint: 'Ex: 800,00',
        group: 'ESSENTIAL_EXPENSE',
        isDefault: true,
      ),
      _EssentialTransaction(
        key: _nextKey++,
        description: 'Academia',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        descriptionController: TextEditingController(text: 'Academia'),
        icon: Icons.fitness_center_rounded,
        hint: 'Ex: 150,00',
        group: 'LIFESTYLE_EXPENSE',
        isDefault: true,
      ),
      _EssentialTransaction(
        key: _nextKey++,
        description: 'Conta de Luz',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        descriptionController: TextEditingController(text: 'Conta de Luz'),
        icon: Icons.lightbulb_rounded,
        hint: 'Ex: 120,00',
        group: 'ESSENTIAL_EXPENSE',
        isDefault: true,
      ),
      _EssentialTransaction(
        key: _nextKey++,
        description: 'Conta de Água',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        descriptionController: TextEditingController(text: 'Conta de Água'),
        icon: Icons.water_drop_rounded,
        hint: 'Ex: 80,00',
        group: 'ESSENTIAL_EXPENSE',
        isDefault: true,
      ),
    ]);
  }

  void _updateDefaultCategories() {
    // Mapping of transaction descriptions to category keywords
    const keywordMap = {
      'Salário': ['salário', 'salario'],
      'Freelance / Renda Extra': ['freelance', 'extra', 'renda extra'],
      'Investimentos': ['investimento', 'investimentos'],
      'Reserva de Emergência': ['emergência', 'emergencia', 'reserva'],
      'Poupança': ['poupança', 'poupanca'],
      'Alimentação': ['alimentação', 'alimentacao', 'comida', 'mercado'],
      'Academia': ['academia', 'esporte', 'fitness'],
      'Conta de Luz': ['luz', 'energia', 'elétrica', 'eletrica'],
      'Conta de Água': ['água', 'agua'],
    };
    
    for (final transaction in _transactions) {
      final categories = transaction.type == 'INCOME' 
          ? _incomeCategories 
          : _expenseCategories;
      
      // 1. First, try to match by exact name (case-insensitive)
      final matchByName = categories
          .where((c) => c.name.toLowerCase() == transaction.description.toLowerCase())
          .toList();
      
      if (matchByName.isNotEmpty) {
        transaction.categoryId = matchByName.first.id;
        continue;
      }
      
      // 2. Try keyword-based matching
      final keywords = keywordMap[transaction.description] ?? [];
      if (keywords.isNotEmpty) {
        final matchByKeyword = categories.where((c) {
          final catName = c.name.toLowerCase();
          return keywords.any((kw) => catName.contains(kw));
        }).toList();
        
        if (matchByKeyword.isNotEmpty) {
          transaction.categoryId = matchByKeyword.first.id;
          continue;
        }
      }
      
      // 3. Then, try to match by name containing description keywords
      final descWords = transaction.description.toLowerCase().split(' ');
      final matchByPartialName = categories
          .where((c) {
            final catName = c.name.toLowerCase();
            // Match if category contains a significant word (>3 chars) from description
            return descWords.any((word) => word.length > 3 && catName.contains(word));
          })
          .toList();
      
      if (matchByPartialName.isNotEmpty) {
        transaction.categoryId = matchByPartialName.first.id;
        continue;
      }
      
      // 4. Fallback to group matching
      final matchByGroup = categories
          .where((c) => c.group == transaction.group)
          .toList();
      
      if (matchByGroup.isNotEmpty) {
        transaction.categoryId = matchByGroup.first.id;
      } else if (categories.isNotEmpty) {
        transaction.categoryId = categories.first.id;
      }
    }
  }

  void _addTransaction({required String type, bool isAporte = false}) {
    final categories = type == 'INCOME' ? _incomeCategories : _expenseCategories;
    int? defaultCategoryId;
    
    if (categories.isNotEmpty) {
      if (isAporte) {
        final savingsCategory = categories.where((c) => c.group == 'SAVINGS' || c.group == 'INVESTMENT').toList();
        defaultCategoryId = savingsCategory.isNotEmpty ? savingsCategory.first.id : categories.first.id;
      } else {
        defaultCategoryId = categories.first.id;
      }
    }

    setState(() {
      _transactions.add(_EssentialTransaction(
        key: _nextKey++,
        description: '',
        type: type,
        amountController: TextEditingController(),
        descriptionController: TextEditingController(),
        icon: type == 'INCOME' ? Icons.attach_money_rounded : Icons.receipt_long_rounded,
        hint: 'Ex: 100,00',
        group: isAporte ? 'SAVINGS' : (type == 'INCOME' ? 'EXTRA_INCOME' : 'ESSENTIAL_EXPENSE'),
        isAporte: isAporte,
        isDefault: false,
        categoryId: defaultCategoryId,
      ));
    });
  }

  void _removeTransaction(_EssentialTransaction transaction) {
    setState(() {
      transaction.amountController.dispose();
      transaction.descriptionController.dispose();
      _transactions.remove(transaction);
    });
  }

  void _nextPage() {
    if (_currentPage == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishSetup();
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _skipSetup() async {
    setState(() => _isSubmitting = true);
    
    try {
      await _repository.completeFirstAccess();
      
      if (mounted) {
        widget.onComplete?.call();
        
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('❌ Erro ao marcar primeiro acesso como concluído: $e');
      
      if (mounted) {
        FeedbackService.showError(
          context,
          'Erro ao salvar configuração. Tente novamente.',
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _finishSetup() async {
    final filledTransactions = _transactions
        .where((t) => t.amountController.text.trim().isNotEmpty)
        .toList();

    if (filledTransactions.length < 3) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Poucos itens preenchidos',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Você preencheu apenas ${filledTransactions.length} transações. '
            'Recomendamos pelo menos 5 para uma análise mais precisa.\n\n'
            'Deseja continuar mesmo assim?',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      int successCount = 0;
      int errorCount = 0;

      for (final transaction in filledTransactions) {
        try {
          final amountText = transaction.amountController.text
              .trim()
              .replaceAll('.', '')
              .replaceAll(',', '.');
          final amount = double.tryParse(amountText);

          if (amount == null || amount <= 0) {
            debugPrint('⚠️ Transação "${transaction.description}" ignorada: valor inválido ($amount)');
            errorCount++;
            continue;
          }

          final description = transaction.descriptionController.text.trim().isNotEmpty
              ? transaction.descriptionController.text.trim()
              : transaction.description;

          debugPrint('📤 Enviando transação: '
              'type=${transaction.type}, '
              'description=$description, '
              'amount=$amount, '
              'categoryId=${transaction.categoryId}, '
              'isRecurring=${transaction.isRecurring}');

          await _repository.createTransaction(
            type: transaction.type,
            description: description,
            amount: amount,
            date: DateTime.now(),
            categoryId: transaction.categoryId,
            isRecurring: transaction.isRecurring,
            recurrenceValue: transaction.isRecurring ? 1 : null,
            recurrenceUnit: transaction.isRecurring ? 'MONTHS' : null,
          );
          debugPrint('✅ Transação "$description" criada com sucesso');
          successCount++;
        } catch (e) {
          debugPrint('❌ Erro ao criar transação "${transaction.description}": $e');
          errorCount++;
        }
      }


      if (mounted) {
        final session = SessionScope.of(context);
        
        // Mark first access as complete
        try {
          await _repository.completeFirstAccess();
          debugPrint('✅ Primeiro acesso marcado como concluído');
        } catch (e) {
          debugPrint('⚠️ Erro ao marcar primeiro acesso: $e');
        }
        
        await session.refreshSession();
        
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!mounted) return;

      if (errorCount == 0) {
        FeedbackService.showSuccess(
          context,
          '🎉 Configuração concluída! $successCount transações adicionadas.',
        );
      } else {
        FeedbackService.showWarning(
          context,
          '$successCount transações adicionadas. $errorCount falharam.',
        );
      }

      widget.onComplete?.call();

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        FeedbackService.showError(
          context,
          'Erro ao criar transações. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showCategorySelector(_EssentialTransaction transaction) {
    List<CategoryModel> categories;
    
    if (transaction.type == 'INCOME') {
      categories = _incomeCategories;
    } else if (transaction.isAporte) {
      // For aportes, only show savings/investment categories
      categories = _expenseCategories
          .where((c) => c.group == 'SAVINGS' || c.group == 'INVESTMENT')
          .toList();
    } else {
      // For regular expenses, exclude savings/investment categories
      categories = _expenseCategories
          .where((c) => c.group != 'SAVINGS' && c.group != 'INVESTMENT')
          .toList();
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecione a categoria',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final isSelected = cat.id == transaction.categoryId;
                  return ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(cat, AppColors.primary),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      cat.name,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected 
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() => transaction.categoryId = cat.id);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildWelcomePage(theme, tokens),
                  _buildTransactionsPage(theme, tokens),
                ],
              ),
            ),

            _buildNavigationButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Configuração Inicial',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: _isSubmitting ? null : _skipSetup,
                child: Text(
                  'Pular',
                  style: TextStyle(
                    color: _isSubmitting ? Colors.grey : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(2, (index) {
              final isActive = index == _currentPage;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 0 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.grey[800],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage(ThemeData theme, AppDecorations tokens) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.celebration_rounded,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Bem-vindo(a)! 🎉',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Realize a configuração inicial!',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: tokens.tileRadius,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Você pode pular esta etapa e adicionar suas transações depois.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsPage(ThemeData theme, AppDecorations tokens) {
    if (_loadingCategories) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final incomeTransactions = _transactions.where((t) => t.type == 'INCOME').toList();
    final aportesTransactions = _transactions.where((t) => t.isAporte).toList();
    final regularExpenses = _transactions.where((t) => t.type == 'EXPENSE' && !t.isAporte).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure suas transações',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Preencha os valores e marque itens recorrentes 🔁',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),

          // Seção de Receitas
          _buildSectionHeader(
            icon: Icons.arrow_upward_rounded,
            title: 'Receitas',
            color: AppColors.success,
            theme: theme,
          ),
          const SizedBox(height: 12),
          ...incomeTransactions.map((t) => _buildTransactionField(t, theme, tokens)),
          _buildAddButton(
            label: 'Adicionar Receita',
            color: AppColors.success,
            onTap: () => _addTransaction(type: 'INCOME'),
          ),
          
          const SizedBox(height: 32),

          // Seção de Aportes
          _buildSectionHeader(
            icon: Icons.savings_rounded,
            title: 'Aportes (Poupança/Investimentos)',
            color: AppColors.primary,
            theme: theme,
          ),
          const SizedBox(height: 12),
          ...aportesTransactions.map((t) => _buildTransactionField(t, theme, tokens)),
          _buildAddButton(
            label: 'Adicionar Aporte',
            color: AppColors.primary,
            onTap: () => _addTransaction(type: 'EXPENSE', isAporte: true),
          ),

          const SizedBox(height: 32),

          // Seção de Despesas
          _buildSectionHeader(
            icon: Icons.arrow_downward_rounded,
            title: 'Despesas',
            color: AppColors.alert,
            theme: theme,
          ),
          const SizedBox(height: 12),
          ...regularExpenses.map((t) => _buildTransactionField(t, theme, tokens)),
          _buildAddButton(
            label: 'Adicionar Despesa',
            color: AppColors.alert,
            onTap: () => _addTransaction(type: 'EXPENSE'),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionField(
    _EssentialTransaction transaction,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    final categories = transaction.type == 'INCOME' 
        ? _incomeCategories 
        : _expenseCategories;
    final selectedCategory = categories.where((c) => c.id == transaction.categoryId).firstOrNull;
    
    final typeColor = transaction.type == 'INCOME'
        ? AppColors.success
        : transaction.isAporte
            ? AppColors.primary
            : AppColors.alert;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.tileRadius,
          border: Border.all(
            color: Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with icon, description, and delete button
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showCategorySelector(transaction),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(selectedCategory, typeColor).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      transaction.icon,
                      color: _getCategoryColor(selectedCategory, typeColor),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: transaction.isDefault
                      ? Text(
                          transaction.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : TextField(
                          controller: transaction.descriptionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Descrição',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                ),
                if (!transaction.isDefault)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                    onPressed: () => _removeTransaction(transaction),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Amount input and controls row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: transaction.amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(),
                    ],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: transaction.hint,
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      prefixText: 'R\$ ',
                      prefixStyle: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: Colors.black45,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Recurrence toggle
                InkWell(
                  onTap: () {
                    setState(() => transaction.isRecurring = !transaction.isRecurring);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: transaction.isRecurring 
                          ? AppColors.primary.withOpacity(0.2)
                          : Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: transaction.isRecurring 
                            ? AppColors.primary 
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 16,
                          color: transaction.isRecurring 
                              ? AppColors.primary 
                              : Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Mensal',
                          style: TextStyle(
                            fontSize: 12,
                            color: transaction.isRecurring 
                                ? AppColors.primary 
                                : Colors.white38,
                            fontWeight: transaction.isRecurring 
                                ? FontWeight.w600 
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Category chip
            if (selectedCategory != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showCategorySelector(transaction),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(selectedCategory, typeColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(selectedCategory, typeColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedCategory.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: _getCategoryColor(selectedCategory, typeColor),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 10,
                        color: _getCategoryColor(selectedCategory, typeColor).withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _previousPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Voltar'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      _currentPage == 0 ? 'Começar' : 'Concluir',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EssentialTransaction {
  _EssentialTransaction({
    required this.key,
    required this.description,
    required this.type,
    required this.amountController,
    required this.descriptionController,
    required this.icon,
    required this.hint,
    required this.group,
    this.isAporte = false,
    this.isDefault = false,
    this.categoryId,
    this.isRecurring = false,
  });

  final int key;
  final String description;
  final String type;
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  final IconData icon;
  final String hint;
  final String group;
  final bool isAporte;
  final bool isDefault;
  int? categoryId;
  bool isRecurring;
}
