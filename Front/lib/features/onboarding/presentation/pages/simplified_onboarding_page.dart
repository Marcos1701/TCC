import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/utils/currency_input_formatter.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation(Colors.purple),
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
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_balance_wallet,
            size: 100,
            color: Colors.purple,
          ),
          const SizedBox(height: 32),
          const Text(
            'Bem-vindo ao GenApp',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Para personalizar sua experiência financeira, precisamos de algumas informações básicas.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple,
              ),
              child: const Text(
                'Iniciar Configuração',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _skipOnboarding,
            child: const Text('Continuar sem configurar'),
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
              'Dados de Configuração Inicial',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Informe valores mensais aproximados para configuração inicial do sistema.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
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
            const SizedBox(height: 4),
            Text(
              'Salário líquido e outras fontes de renda recorrentes',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _incomeController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ex: 3.500,00',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixText: 'R\$ ',
                prefixStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: _incomeError != null
                      ? const BorderSide(color: Colors.red, width: 1.5)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _incomeError != null ? Colors.red : Colors.purple,
                    width: 2,
                  ),
                ),
                errorText: _incomeError,
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              onChanged: (value) {
                setState(() {
                  _monthlyIncome = CurrencyInputFormatter.parse(value);
                  _incomeError = null;
                  // Re-validar gastos quando a renda muda
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
              '🏠 Despesas Essenciais Mensais',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Soma de: Habitação + Alimentação + Transporte + Contas básicas',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 4),
            Text(
              'Ex: Aluguel (R\$ 800) + Supermercado (R\$ 600) + Transporte (R\$ 300) + Contas (R\$ 300) = R\$ 2.000',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _expenseController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ex: 2.000,00',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixText: 'R\$ ',
                prefixStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: _expenseError != null
                      ? const BorderSide(color: Colors.red, width: 1.5)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _expenseError != null ? Colors.red : Colors.purple,
                    width: 2,
                  ),
                ),
                errorText: _expenseError,
                errorStyle: const TextStyle(color: Colors.redAccent),
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

            const SizedBox(height: 16),

            // Resumo visual dos valores
            if (_monthlyIncome > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _canSubmit
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Renda mensal',
                      _currency.format(_monthlyIncome),
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Despesas essenciais',
                      '- ${_currency.format(_essentialExpenses)}',
                      Colors.red,
                    ),
                    const Divider(color: Colors.grey, height: 24),
                    _buildSummaryRow(
                      'Saldo disponível',
                      _currency.format(_monthlyIncome - _essentialExpenses),
                      (_monthlyIncome - _essentialExpenses) >= 0
                          ? Colors.blue
                          : Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _canSubmit ? _submitOnboarding : _showValidationErrors,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      _canSubmit ? Colors.purple : Colors.grey[700],
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Continuar',
                        style: TextStyle(fontSize: 16),
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
                child: const Text('Voltar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionStep() {
    if (_insights == null) {
      return const Center(child: CircularProgressIndicator());
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
          const Icon(
            Icons.check_circle,
            size: 100,
            color: Colors.green,
          ),
          const SizedBox(height: 32),
          const Text(
            'Configuração Concluída!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Com base nos dados informados, calculamos seus indicadores financeiros iniciais:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          _buildInsightCard(
            icon: Icons.trending_up,
            title: 'Capacidade de Poupança Mensal',
            value: _currency.format(balance),
            subtitle: '${savingsRate.toStringAsFixed(1)}% da renda mensal',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildInsightCard(
            icon: Icons.lightbulb_outline,
            title: 'Recomendação',
            value: recommendation,
            subtitle: '',
            color: Colors.amber,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple,
              ),
              child: const Text(
                'Começar a usar',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
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
    // Validar antes de enviar
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
        // Invalida o cache para forçar atualização da home
        CacheManager().invalidateAll();

        setState(() {
          _insights = result;
          _isSubmitting = false;
        });

        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
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
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showValidationErrors() {
    _validateFields();
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _completeOnboarding() {
    // Rastreia conclusão do onboarding
    final daysToComplete =
        DateTime.now().difference(_onboardingStartTime).inDays;
    AnalyticsService.trackOnboardingCompleted(
      daysToComplete: daysToComplete,
      stepsCompleted: 3,
    );

    // Invalida o cache novamente para garantir atualização completa
    CacheManager().invalidateAll();

    // Fecha a página de onboarding e retorna para o AuthFlow gerenciar a navegação
    Navigator.of(context).pop(true); // Retorna true para indicar que completou
  }

  void _skipOnboarding() {
    // Fecha a página de onboarding sem completar
    Navigator.of(context).pop();
  }
}
