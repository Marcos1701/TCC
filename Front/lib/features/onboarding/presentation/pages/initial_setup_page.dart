import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/storage/onboarding_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

/// Formatador de moeda brasileiro para TextFields
/// Permite digitar apenas números, formatando automaticamente como moeda
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Remove tudo que não é número
    String cleanedText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanedText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Converte para double (últimos 2 dígitos são centavos)
    final double value = double.parse(cleanedText) / 100;

    // Formata como moeda brasileira sem símbolo
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

/// Tela de configuração inicial para novos usuários
/// Permite adicionar transações essenciais rapidamente no primeiro acesso
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

  // Lista de transações essenciais a serem criadas
  final List<_EssentialTransaction> _transactions = [];
  
  // Categorias disponíveis
  List<CategoryModel> _incomeCategories = [];
  List<CategoryModel> _expenseCategories = [];
  bool _loadingCategories = true;

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
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final income = await _repository.fetchCategories(type: 'INCOME');
      final expense = await _repository.fetchCategories(type: 'EXPENSE');
      
      setState(() {
        _incomeCategories = income;
        _expenseCategories = expense;
        _loadingCategories = false;
      });
      
      // Atualiza categorias padrão nas transações
      _updateDefaultCategories();
    } catch (e) {
      setState(() => _loadingCategories = false);
      if (mounted) {
        FeedbackService.showError(
          context,
          'Erro ao carregar categorias. Tente novamente.',
        );
      }
    }
  }

  void _initializeDefaultTransactions() {
    // Transações de receita sugeridas
    _transactions.addAll([
      _EssentialTransaction(
        description: 'Salário',
        type: 'INCOME',
        amountController: TextEditingController(),
        icon: Icons.account_balance_wallet_rounded,
        hint: 'Ex: 3500,00',
        group: 'REGULAR_INCOME',
      ),
      _EssentialTransaction(
        description: 'Investimentos',
        type: 'INCOME',
        amountController: TextEditingController(),
        icon: Icons.trending_up_rounded,
        hint: 'Ex: 500,00',
        group: 'INVESTMENT',
      ),
      _EssentialTransaction(
        description: 'Reserva de Emergência',
        type: 'INCOME',
        amountController: TextEditingController(),
        icon: Icons.savings_rounded,
        hint: 'Ex: 1000,00',
        group: 'SAVINGS',
      ),
      _EssentialTransaction(
        description: 'Poupança',
        type: 'INCOME',
        amountController: TextEditingController(),
        icon: Icons.account_balance_rounded,
        hint: 'Ex: 300,00',
        group: 'SAVINGS',
      ),
    ]);

    // Transações de despesa sugeridas
    _transactions.addAll([
      _EssentialTransaction(
        description: 'Alimentação',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        icon: Icons.restaurant_rounded,
        hint: 'Ex: 800,00',
        group: 'ESSENTIAL_EXPENSE',
      ),
      _EssentialTransaction(
        description: 'Academia',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        icon: Icons.fitness_center_rounded,
        hint: 'Ex: 150,00',
        group: 'LIFESTYLE_EXPENSE',
      ),
      _EssentialTransaction(
        description: 'Conta de Luz',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        icon: Icons.lightbulb_rounded,
        hint: 'Ex: 120,00',
        group: 'ESSENTIAL_EXPENSE',
      ),
      _EssentialTransaction(
        description: 'Conta de Água',
        type: 'EXPENSE',
        amountController: TextEditingController(),
        icon: Icons.water_drop_rounded,
        hint: 'Ex: 80,00',
        group: 'ESSENTIAL_EXPENSE',
      ),
    ]);
  }

  void _updateDefaultCategories() {
    for (final transaction in _transactions) {
      final categories = transaction.type == 'INCOME' 
          ? _incomeCategories 
          : _expenseCategories;
      
      // Tenta encontrar categoria do grupo correspondente
      transaction.categoryId = categories
          .where((c) => c.group == transaction.group)
          .firstOrNull
          ?.id;
      
      // Se não encontrou, pega primeira categoria do tipo
      transaction.categoryId ??= categories.firstOrNull?.id;
    }
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
    await OnboardingStorage.markOnboardingComplete();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _finishSetup() async {
    // Valida se há pelo menos 5 transações preenchidas
    final filledTransactions = _transactions
        .where((t) => t.amountController.text.trim().isNotEmpty)
        .toList();

    if (filledTransactions.length < 5) {
      FeedbackService.showWarning(
        context,
        'Adicione pelo menos 5 transações para começar! 🎯',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      int successCount = 0;
      int errorCount = 0;

      // Cria todas as transações preenchidas
      for (final transaction in filledTransactions) {
        try {
          // Remove formatação e converte para double
          final amountText = transaction.amountController.text
              .trim()
              .replaceAll('.', '') // Remove separador de milhares
              .replaceAll(',', '.'); // Troca vírgula por ponto
          final amount = double.tryParse(amountText);

          if (amount == null || amount <= 0) {
            errorCount++;
            continue;
          }

          await _repository.createTransaction(
            type: transaction.type,
            description: transaction.description,
            amount: amount,
            date: DateTime.now(),
            categoryId: transaction.categoryId,
          );
          successCount++;
        } catch (e) {
          debugPrint('Erro ao criar transação: $e');
          errorCount++;
        }
      }

      // Marca onboarding como completo
      await OnboardingStorage.markOnboardingComplete();

      // Atualiza sessão para refletir as novas transações
      if (mounted) {
        final session = SessionScope.of(context);
        await session.refreshSession();
        
        // Pequeno delay para garantir que tudo foi atualizado
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

      // Chama callback para notificar conclusão
      widget.onComplete?.call();

      Navigator.of(context).pop(true); // Retorna true indicando sucesso
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header com progresso
            _buildHeader(theme),
            
            // Conteúdo das páginas
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

            // Botões de navegação
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
          // Indicador de progresso
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
            'Vamos configurar suas finanças em minutos!',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            icon: Icons.speed_rounded,
            title: 'Configuração Rápida',
            description:
                'Adicione suas transações essenciais em poucos passos.',
            theme: theme,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Sugestões Inteligentes',
            description:
                'Sugerimos 8 transações comuns para facilitar seu início.',
            theme: theme,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            icon: Icons.check_circle_outline_rounded,
            title: 'Mínimo de 5',
            description:
                'Adicione pelo menos 5 transações para começar com o pé direito.',
            theme: theme,
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

    final incomeTransactions = _transactions.where((t) => t.type == 'INCOME');
    final expenseTransactions = _transactions.where((t) => t.type == 'EXPENSE');

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
            'Adicione pelo menos 5 transações para começar 🎯',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),

          // Receitas
          _buildSectionHeader(
            icon: Icons.arrow_upward_rounded,
            title: 'Receitas',
            color: AppColors.success,
            theme: theme,
          ),
          const SizedBox(height: 12),
          ...incomeTransactions.map((t) => _buildTransactionField(t, theme, tokens)),
          
          const SizedBox(height: 32),

          // Despesas
          _buildSectionHeader(
            icon: Icons.arrow_downward_rounded,
            title: 'Despesas',
            color: AppColors.alert,
            theme: theme,
          ),
          const SizedBox(height: 12),
          ...expenseTransactions.map((t) => _buildTransactionField(t, theme, tokens)),
          
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

  Widget _buildTransactionField(
    _EssentialTransaction transaction,
    ThemeData theme,
    AppDecorations tokens,
  ) {
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: transaction.type == 'INCOME'
                    ? AppColors.success.withOpacity(0.2)
                    : AppColors.alert.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                transaction.icon,
                color: transaction.type == 'INCOME'
                    ? AppColors.success
                    : AppColors.alert,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
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
                ],
              ),
            ),
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
    required this.description,
    required this.type,
    required this.amountController,
    required this.icon,
    required this.hint,
    required this.group,
  });

  final String description;
  final String type;
  final TextEditingController amountController;
  final IconData icon;
  final String hint;
  final String group;
  int? categoryId;
}
