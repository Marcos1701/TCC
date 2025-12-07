import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class SimplifiedOnboardingPage extends StatefulWidget {
  const SimplifiedOnboardingPage({super.key});

  @override
  State<SimplifiedOnboardingPage> createState() =>
      _SimplifiedOnboardingPageState();
}

class _SimplifiedOnboardingPageState extends State<SimplifiedOnboardingPage> {
  final PageController _pageController = PageController();
  final FinanceRepository _repository = FinanceRepository();
  final _formKey = GlobalKey<FormState>();
  final _incomeController = TextEditingController();
  final _expenseController = TextEditingController();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  int _currentPage = 0;
  double _monthlyIncome = 0;
  double _essentialExpenses = 0;
  bool _isSubmitting = false;
  Map<String, dynamic>? _insights;
  String? _incomeError;
  String? _expenseError;
  final DateTime _onboardingStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackOnboardingStarted();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _incomeController.dispose();
    _expenseController.dispose();
    super.dispose();
  }

  void _validateFields() {
    setState(() {
      _incomeError = null;
      _expenseError = null;

      if (_monthlyIncome <= 0) {
        _incomeError = 'Informe sua renda mensal';
      } else if (_monthlyIncome < 100) {
        _incomeError = 'A renda mensal deve ser pelo menos R\$ 100,00';
      }

      if (_essentialExpenses < 0) {
        _expenseError = 'O valor não pode ser negativo';
      } else if (_essentialExpenses > _monthlyIncome && _monthlyIncome > 0) {
        _expenseError = 'Gastos essenciais não podem exceder a renda';
      }
    });
  }

  bool get _canSubmit =>
      _monthlyIncome >= 100 &&
      _essentialExpenses >= 0 &&
      _essentialExpenses <= _monthlyIncome &&
      !_isSubmitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decorations = theme.extension<AppDecorations>() ?? AppDecorations.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: decorations.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentPage + 1) / 3,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildWelcomeStep(),
                    _buildBasicInfoStep(),
                    _buildCompletionStep(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 80,
              color: AppColors.highlight,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Sua Jornada Financeira',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Comece missões personalizadas, ganhe XP e evolua seu nível financeiro.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[300],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Iniciar Calibragem',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _skipOnboarding,
            child: Text(
               'Pular calibração (Modo Default)',
               style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calibragem de Perfil',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estes dados calibrarão a dificuldade das suas missões iniciais e metas de economia.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              '💵 Renda Mensal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _incomeController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                hint: 'Ex: 3.500,00',
                errorText: _incomeError,
              ),
              onChanged: (value) {
                setState(() {
                  _monthlyIncome = CurrencyInputFormatter.parse(value);
                  _incomeError = null;
                  if (_essentialExpenses > _monthlyIncome &&
                      _monthlyIncome > 0) {
                    _expenseError =
                        'Gastos essenciais não podem exceder a renda';
                  } else {
                    _expenseError = null;
                  }
                });
              },
            ),

            const SizedBox(height: 24),

            const Text(
              '🏠 Gastos Essenciais (Fixo)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _expenseController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                hint: 'Ex: 2.000,00',
                errorText: _expenseError,
              ),
              onChanged: (value) {
                setState(() {
                  _essentialExpenses = CurrencyInputFormatter.parse(value);
                  if (_essentialExpenses > _monthlyIncome &&
                      _monthlyIncome > 0) {
                    _expenseError =
                        'Gastos essenciais não podem exceder a renda';
                  } else {
                    _expenseError = null;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Inclui: Moradia + Alimentação + Transporte + Contas básicas',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 32),

            if (_monthlyIncome > 0) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _canSubmit
                        ? AppColors.support.withOpacity(0.3)
                        : AppColors.highlight.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Renda',
                      _currency.format(_monthlyIncome),
                      AppColors.success,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      'Essenciais',
                      '- ${_currency.format(_essentialExpenses)}',
                      AppColors.alert,
                    ),
                    Divider(color: Colors.grey[800], height: 32),
                    _buildSummaryRow(
                      'Margem Livre Estimada',
                      _currency.format(_monthlyIncome - _essentialExpenses),
                      (_monthlyIncome - _essentialExpenses) >= 0
                          ? AppColors.highlight
                          : AppColors.alert,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _canSubmit ? _submitOnboarding : _showValidationErrors,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor:
                      _canSubmit ? AppColors.primary : Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Calibrar Perfil',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: const Text('Voltar', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionStep() {
    if (_insights == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.highlight));
    }

    final insights = _insights!['insights'] as Map<String, dynamic>;
    final balance = insights['monthly_balance'] as double;
    final savingsRate = insights['savings_rate'] as double;
    final recommendation = insights['recommendation'] as String;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.support.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.support.withOpacity(0.5)),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 80,
              color: AppColors.support,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Perfil Criado!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Seu diagnóstico inicial foi concluído. Veja seus primeiros indicadores:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildInsightCard(
            icon: Icons.trending_up,
            title: 'Potencial de Poupança',
            value: _currency.format(balance),
            subtitle: '${savingsRate.toStringAsFixed(1)}% da renda identificados como livres',
            color: AppColors.support,
          ),
          const SizedBox(height: 16),
          _buildInsightCard(
            icon: Icons.auto_awesome,
            title: 'Estratégia Recomendada',
            value: recommendation,
            subtitle: '',
            color: AppColors.highlight,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Acessar Gamificação',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, String? errorText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      prefixText: 'R\$ ',
      prefixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      filled: true,
      fillColor: Colors.black26,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: errorText != null
            ? const BorderSide(color: AppColors.alert, width: 1.5)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: errorText != null ? AppColors.alert : AppColors.primary,
          width: 2,
        ),
      ),
      errorText: errorText,
      errorStyle: const TextStyle(color: AppColors.alert),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
               color: color.withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOnboarding() async {
    _validateFields();
    if (_incomeError != null || _expenseError != null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _repository.completeSimplifiedOnboarding(
        monthlyIncome: _monthlyIncome,
        essentialExpenses: _essentialExpenses,
      );

      if (mounted) {
        CacheManager().invalidateAll();

        setState(() {
          _insights = result;
          _isSubmitting = false;
        });

        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);

        String errorMessage = 'Erro ao processar configuração';
        final errorStr = e.toString();

        if (errorStr.contains('essenciais não podem exceder')) {
          errorMessage = 'Gastos essenciais não podem exceder a renda';
          setState(() {
            _expenseError = errorMessage;
          });
        } else if (errorStr.contains('Renda mensal deve ser maior')) {
          errorMessage = 'Informe uma renda mensal válida';
          setState(() {
            _incomeError = errorMessage;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppColors.alert,
            ),
          );
        }
      }
    }
  }

  void _showValidationErrors() {
    _validateFields();
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: Colors.grey[400],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _completeOnboarding() {
    final daysToComplete =
        DateTime.now().difference(_onboardingStartTime).inDays;
    AnalyticsService.trackOnboardingCompleted(
      daysToComplete: daysToComplete,
      stepsCompleted: 3,
    );

    CacheManager().invalidateAll();

    Navigator.of(context).pop(true);
  }

  void _skipOnboarding() {
    Navigator.of(context).pop();
  }
}
