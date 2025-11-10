# Exemplos Práticos de Implementação - Melhorias de UX

## 🎯 Exemplos de Código para Implementar as Melhorias

Este documento complementa `ANALISE_USABILIDADE_MELHORIAS.md` com exemplos práticos de código Flutter e Python/Django.

---

## 1. Simplificação de Indicadores Financeiros

### 1.1. Widget de Indicador Amigável (Flutter)

**ANTES** (complexo):
```dart
Text('TPS: ${dashboard.tps.toStringAsFixed(1)}%')
```

**DEPOIS** (amigável):

```dart
class FriendlyIndicatorCard extends StatelessWidget {
  final String title;
  final double value;
  final double target;
  final String formatType; // 'percentage', 'currency', 'months'
  final String? subtitle;
  
  const FriendlyIndicatorCard({
    required this.title,
    required this.value,
    required this.target,
    this.formatType = 'percentage',
    this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / target).clamp(0.0, 1.0);
    final status = _getStatus(progress);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status.icon, color: status.color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatValue(value),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: status.color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation(status.color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            'Meta: ${_formatValue(target)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double val) {
    switch (formatType) {
      case 'currency':
        return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(val);
      case 'months':
        return '${val.toStringAsFixed(1)} meses';
      case 'percentage':
      default:
        return '${val.toStringAsFixed(0)}%';
    }
  }

  _IndicatorStatus _getStatus(double progress) {
    if (progress >= 1.0) {
      return _IndicatorStatus(
        label: 'Excelente!',
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } else if (progress >= 0.7) {
      return _IndicatorStatus(
        label: 'Bom',
        color: Colors.lightGreen,
        icon: Icons.trending_up,
      );
    } else if (progress >= 0.4) {
      return _IndicatorStatus(
        label: 'Atenção',
        color: Colors.orange,
        icon: Icons.warning_amber,
      );
    } else {
      return _IndicatorStatus(
        label: 'Crítico',
        color: Colors.red,
        icon: Icons.error_outline,
      );
    }
  }

  Widget _buildStatusBadge(_IndicatorStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}

class _IndicatorStatus {
  final String label;
  final Color color;
  final IconData icon;

  _IndicatorStatus({
    required this.label,
    required this.color,
    required this.icon,
  });
}
```

**Uso**:
```dart
// Em vez de mostrar "TPS: 15%"
FriendlyIndicatorCard(
  title: 'Você está guardando',
  value: dashboard.summary.totalIncome - dashboard.summary.totalExpense,
  target: dashboard.profile.targetTps / 100 * dashboard.summary.totalIncome,
  formatType: 'currency',
  subtitle: '${dashboard.tps.toStringAsFixed(0)}% da sua renda',
)
```

---

## 2. Simplificação de Navegação

### 2.1. Nova Estrutura de Navegação (Flutter)

```dart
class SimplifiedRootShell extends StatefulWidget {
  const SimplifiedRootShell({super.key});

  @override
  State<SimplifiedRootShell> createState() => _SimplifiedRootShellState();
}

class _SimplifiedRootShellState extends State<SimplifiedRootShell> {
  int _currentIndex = 0;

  final List<_NavTab> _tabs = [
    _NavTab(
      label: 'Início',
      icon: Icons.home_rounded,
      activeIcon: Icons.home,
      builder: () => const UnifiedHomePage(), // Nova página unificada
    ),
    _NavTab(
      label: 'Finanças',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      builder: () => const FinancesPage(), // Combina transações + análises
    ),
    _NavTab(
      label: 'Perfil',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      builder: () => const ProfilePage(), // Novo: nível, conquistas, config
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs.map((tab) => tab.builder()).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: _tabs.map((tab) => NavigationDestination(
          icon: Icon(tab.icon),
          selectedIcon: Icon(tab.activeIcon),
          label: tab.label,
        )).toList(),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget Function() builder;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.builder,
  });
}
```

### 2.2. Página Inicial Unificada

```dart
class UnifiedHomePage extends StatelessWidget {
  const UnifiedHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Olá!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh logic
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Resumo Financeiro do Mês
            _buildMonthSummaryCard(),
            const SizedBox(height: 16),
            
            // Desafio da Semana (missão ativa)
            _buildWeeklyChallengeCard(),
            const SizedBox(height: 16),
            
            // Progresso de Metas (resumido)
            _buildGoalsProgress(),
            const SizedBox(height: 16),
            
            // Últimas Transações
            _buildRecentTransactions(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTransaction(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova transação'),
      ),
    );
  }

  Widget _buildMonthSummaryCard() {
    // Card simples e visual com entradas, saídas e saldo
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este mês',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: 'Entrou',
                    value: 'R\$ 3.500',
                    icon: Icons.arrow_downward,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: 'Saiu',
                    value: 'R\$ 2.200',
                    icon: Icons.arrow_upward,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saldo',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  'R\$ 1.300',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChallengeCard() {
    return Card(
      color: Colors.purple[900],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Desafio da Semana',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '🍕 Gastar menos em delivery',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: 0.6,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation(Colors.amber),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('R\$ 120 / R\$ 200'),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '+50 pontos',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
```

---

## 3. Simplificação de Criação de Metas

### 3.1. Wizard Simplificado de Metas

```dart
class SimpleGoalWizard extends StatefulWidget {
  const SimpleGoalWizard({super.key});

  @override
  State<SimpleGoalWizard> createState() => _SimpleGoalWizardState();
}

class _SimpleGoalWizardState extends State<SimpleGoalWizard> {
  int _step = 0;
  GoalType? _selectedType;
  String _title = '';
  double _targetAmount = 0;
  DateTime? _deadline;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Meta'),
        actions: [
          if (_step > 0)
            TextButton(
              onPressed: () => setState(() => _step--),
              child: const Text('Voltar'),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentStep(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _canProceed() ? _proceed : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_step == 3 ? 'Criar Meta' : 'Continuar'),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _Step1GoalType(
          selectedType: _selectedType,
          onTypeSelected: (type) => setState(() => _selectedType = type),
        );
      case 1:
        return _Step2GoalTitle(
          goalType: _selectedType!,
          title: _title,
          onTitleChanged: (title) => setState(() => _title = title),
        );
      case 2:
        return _Step3TargetAmount(
          amount: _targetAmount,
          onAmountChanged: (amount) => setState(() => _targetAmount = amount),
        );
      case 3:
        return _Step4Deadline(
          deadline: _deadline,
          onDeadlineChanged: (date) => setState(() => _deadline = date),
        );
      default:
        return const SizedBox();
    }
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _selectedType != null;
      case 1:
        return _title.trim().isNotEmpty;
      case 2:
        return _targetAmount > 0;
      case 3:
        return true; // Deadline é opcional
      default:
        return false;
    }
  }

  void _proceed() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _createGoal();
    }
  }

  Future<void> _createGoal() async {
    // Criar meta com os dados coletados
    final goal = GoalModel(
      title: _title,
      goalType: _selectedType!,
      targetAmount: _targetAmount,
      deadline: _deadline,
      autoUpdate: true, // Sempre ativo por padrão
      trackingPeriod: TrackingPeriod.total, // Padrão simplificado
    );

    // Enviar para API
    await _repository.createGoal(goal);
    
    if (mounted) {
      Navigator.pop(context, goal);
    }
  }
}

class _Step1GoalType extends StatelessWidget {
  final GoalType? selectedType;
  final ValueChanged<GoalType> onTypeSelected;

  const _Step1GoalType({
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'O que você quer fazer?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Escolha o tipo de meta',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          _GoalTypeOption(
            icon: Icons.savings,
            title: 'Juntar dinheiro',
            description: 'Para comprar algo ou criar uma reserva',
            isSelected: selectedType == GoalType.savings,
            onTap: () => onTypeSelected(GoalType.savings),
          ),
          const SizedBox(height: 16),
          _GoalTypeOption(
            icon: Icons.trending_down,
            title: 'Reduzir gastos',
            description: 'Economizar em uma categoria específica',
            isSelected: selectedType == GoalType.categoryExpense,
            onTap: () => onTypeSelected(GoalType.categoryExpense),
          ),
        ],
      ),
    );
  }
}

class _GoalTypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalTypeOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple[900] : Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.grey[800]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.purple.withOpacity(0.2)
                    : Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: isSelected ? Colors.purple : Colors.grey[400],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.purple,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
```

---

## 4. Onboarding Simplificado

### 4.1. Novo Fluxo de Onboarding (3 Passos)

```dart
class SimplifiedOnboarding extends StatefulWidget {
  const SimplifiedOnboarding({super.key});

  @override
  State<SimplifiedOnboarding> createState() => _SimplifiedOnboardingState();
}

class _SimplifiedOnboardingState extends State<SimplifiedOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  double _monthlyIncome = 0;
  double _essentialExpenses = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de progresso
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
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
            'Bem-vindo!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Vamos começar configurando suas finanças.\nSó precisamos de 2 informações básicas.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 16,
              ),
            ),
            child: const Text('Começar'),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações básicas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Isso nos ajuda a personalizar sua experiência',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          
          // Renda mensal
          const Text(
            '💵 Quanto você ganha por mês?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              hintText: 'Ex: 3.500,00',
              prefixText: 'R\$ ',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              // Parse currency to double
              final parsed = CurrencyInputFormatter.parse(value);
              setState(() => _monthlyIncome = parsed);
            },
          ),
          
          const SizedBox(height: 32),
          
          // Gastos essenciais
          const Text(
            '🏠 Quanto você gasta com o básico?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Aluguel, mercado, contas de água/luz, etc.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              hintText: 'Ex: 2.000,00',
              prefixText: 'R\$ ',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final parsed = CurrencyInputFormatter.parse(value);
              setState(() => _essentialExpenses = parsed);
            },
          ),
          
          const Spacer(),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _monthlyIncome > 0 && _essentialExpenses > 0
                  ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStep() {
    final balance = _monthlyIncome - _essentialExpenses;
    final savingsRate = (_monthlyIncome > 0) 
        ? ((balance / _monthlyIncome) * 100).toStringAsFixed(0)
        : '0';

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
            'Tudo pronto!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Com base nas suas informações:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          
          // Insights
          _buildInsightCard(
            icon: Icons.trending_up,
            title: 'Você pode guardar',
            value: NumberFormat.currency(
              locale: 'pt_BR',
              symbol: 'R\$',
            ).format(balance),
            subtitle: '$savingsRate% da sua renda',
            color: Colors.green,
          ),
          
          const SizedBox(height: 16),
          
          _buildInsightCard(
            icon: Icons.lightbulb_outline,
            title: 'Dica',
            value: 'Comece guardando 10%',
            subtitle: 'Depois aumente aos poucos',
            color: Colors.amber,
          ),
          
          const Spacer(),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Começar a usar'),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    // Criar transações básicas no backend
    await _repository.createInitialTransactions(
      monthlyIncome: _monthlyIncome,
      essentialExpenses: _essentialExpenses,
    );

    // Marcar onboarding como completo
    await _repository.completeOnboarding();

    if (mounted) {
      // Navegar para a tela principal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RootShell()),
      );
    }
  }
}
```

---

## 5. Melhorias no Backend (Django)

### 5.1. Serializer Simplificado para Indicadores

```python
# finance/serializers.py

class FriendlyIndicatorsSerializer(serializers.Serializer):
    """
    Serializer que apresenta indicadores de forma mais amigável.
    """
    
    # Dados brutos (para referência)
    raw_tps = serializers.DecimalField(
        max_digits=6, 
        decimal_places=2, 
        source='cached_tps',
        read_only=True
    )
    raw_rdr = serializers.DecimalField(
        max_digits=6, 
        decimal_places=2, 
        source='cached_rdr',
        read_only=True
    )
    raw_ili = serializers.DecimalField(
        max_digits=6, 
        decimal_places=2, 
        source='cached_ili',
        read_only=True
    )
    
    # Apresentação amigável
    savings_amount = serializers.SerializerMethodField()
    savings_status = serializers.SerializerMethodField()
    fixed_expenses_amount = serializers.SerializerMethodField()
    fixed_expenses_status = serializers.SerializerMethodField()
    emergency_fund_months = serializers.SerializerMethodField()
    emergency_fund_status = serializers.SerializerMethodField()
    
    def get_savings_amount(self, profile):
        """Calcula valor absoluto de poupança mensal."""
        total_income = profile.cached_total_income or Decimal('0')
        tps = profile.cached_tps or Decimal('0')
        return float((total_income * tps / 100).quantize(Decimal('0.01')))
    
    def get_savings_status(self, profile):
        """Define status visual da poupança."""
        tps = profile.cached_tps or Decimal('0')
        target = profile.target_tps
        
        if tps >= target:
            return {"level": "excellent", "color": "#4CAF50", "label": "Excelente!"}
        elif tps >= target * 0.7:
            return {"level": "good", "color": "#8BC34A", "label": "Bom"}
        elif tps >= target * 0.4:
            return {"level": "warning", "color": "#FF9800", "label": "Atenção"}
        else:
            return {"level": "critical", "color": "#F44336", "label": "Crítico"}
    
    def get_fixed_expenses_amount(self, profile):
        """Calcula valor absoluto de despesas fixas."""
        total_income = profile.cached_total_income or Decimal('0')
        rdr = profile.cached_rdr or Decimal('0')
        return float((total_income * rdr / 100).quantize(Decimal('0.01')))
    
    def get_fixed_expenses_status(self, profile):
        """Define status visual das despesas fixas."""
        rdr = profile.cached_rdr or Decimal('0')
        target = profile.target_rdr
        
        # Inverso: menor é melhor
        if rdr <= target:
            return {"level": "excellent", "color": "#4CAF50", "label": "Saudável"}
        elif rdr <= target * 1.2:
            return {"level": "warning", "color": "#FF9800", "label": "Atenção"}
        else:
            return {"level": "critical", "color": "#F44336", "label": "Crítico"}
    
    def get_emergency_fund_months(self, profile):
        """Retorna ILI formatado."""
        ili = profile.cached_ili or Decimal('0')
        return float(ili)
    
    def get_emergency_fund_status(self, profile):
        """Define status visual da reserva de emergência."""
        ili = profile.cached_ili or Decimal('0')
        target = profile.target_ili
        
        if ili >= target:
            return {"level": "excellent", "color": "#4CAF50", "label": "Protegido"}
        elif ili >= target * 0.6:
            return {"level": "good", "color": "#8BC34A", "label": "Quase lá"}
        elif ili >= target * 0.3:
            return {"level": "warning", "color": "#FF9800", "label": "Construindo"}
        else:
            return {"level": "critical", "color": "#F44336", "label": "Vulnerável"}
```

### 5.2. Endpoint Simplificado para Onboarding

```python
# finance/views.py

class SimplifiedOnboardingView(APIView):
    """
    Endpoint para onboarding simplificado.
    Recebe apenas renda mensal e gastos essenciais.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        """
        Criar transações iniciais baseadas em 2 valores.
        """
        monthly_income = Decimal(request.data.get('monthly_income', 0))
        essential_expenses = Decimal(request.data.get('essential_expenses', 0))
        
        # Validações básicas
        if monthly_income <= 0:
            return Response(
                {"error": "Renda mensal deve ser maior que zero."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if essential_expenses < 0:
            return Response(
                {"error": "Gastos essenciais não podem ser negativos."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if essential_expenses > monthly_income:
            return Response(
                {"error": "Gastos essenciais não podem exceder a renda."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        user = request.user
        
        # Buscar ou criar categorias padrão
        income_category, _ = Category.objects.get_or_create(
            user=user,
            name="Salário",
            type=Category.CategoryType.INCOME,
            defaults={'group': Category.CategoryGroup.REGULAR_INCOME}
        )
        
        expense_category, _ = Category.objects.get_or_create(
            user=user,
            name="Gastos Essenciais",
            type=Category.CategoryType.EXPENSE,
            defaults={'group': Category.CategoryGroup.ESSENTIAL_EXPENSE}
        )
        
        # Criar transações básicas
        with transaction.atomic():
            # Transação de renda
            Transaction.objects.create(
                user=user,
                description="Salário mensal",
                amount=monthly_income,
                category=income_category,
                type=Transaction.TransactionType.INCOME,
                date=timezone.now().date()
            )
            
            # Transação de despesa essencial
            if essential_expenses > 0:
                Transaction.objects.create(
                    user=user,
                    description="Gastos essenciais do mês",
                    amount=essential_expenses,
                    category=expense_category,
                    type=Transaction.TransactionType.EXPENSE,
                    date=timezone.now().date()
                )
            
            # Marcar onboarding como completo
            profile = user.userprofile
            profile.is_first_access = False
            profile.save()
            
            # Recalcular indicadores
            from finance.services import FinancialIndicatorsService
            FinancialIndicatorsService.update_cached_indicators(user)
        
        # Retornar insights iniciais
        balance = monthly_income - essential_expenses
        savings_rate = (balance / monthly_income * 100) if monthly_income > 0 else 0
        
        return Response({
            "success": True,
            "insights": {
                "monthly_balance": float(balance),
                "savings_rate": float(savings_rate),
                "can_save": balance > 0,
                "recommendation": self._get_recommendation(savings_rate)
            }
        }, status=status.HTTP_201_CREATED)
    
    def _get_recommendation(self, savings_rate: Decimal) -> str:
        """Gera recomendação baseada na taxa de poupança."""
        if savings_rate >= 20:
            return "Excelente! Você está no caminho certo para construir patrimônio."
        elif savings_rate >= 10:
            return "Bom começo! Tente aumentar gradualmente sua taxa de poupança."
        elif savings_rate >= 5:
            return "Você está começando a poupar. Procure oportunidades para economizar mais."
        else:
            return "Revise seus gastos e tente encontrar áreas onde pode economizar."
```

---

## 6. Utilitários e Helpers

### 6.1. Currency Input Formatter Melhorado

```dart
// lib/core/utils/currency_input_formatter.dart

class CurrencyInputFormatter extends TextInputFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

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
    final String formatted = _formatter.format(value).trim();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Helper para converter texto formatado de volta para double
  static double parse(String formattedText) {
    if (formattedText.isEmpty) return 0;
    
    // Remove tudo que não é número ou vírgula
    final cleaned = formattedText.replaceAll(RegExp(r'[^\d,]'), '');
    
    // Substitui vírgula por ponto
    final normalized = cleaned.replaceAll(',', '.');
    
    return double.tryParse(normalized) ?? 0;
  }

  /// Helper para formatar double como string de moeda
  static String format(double value) {
    return _formatter.format(value).trim();
  }
}
```

---

## 7. Constantes e Configurações

### 7.1. Strings Amigáveis Centralizadas

```dart
// lib/core/constants/user_friendly_strings.dart

class UserFriendlyStrings {
  // Indicadores Financeiros
  static const savingsLabel = 'Você está guardando';
  static const fixedExpensesLabel = 'Gastos fixos mensais';
  static const emergencyFundLabel = 'Reserva de emergência';
  
  // Status
  static const statusExcellent = 'Excelente!';
  static const statusGood = 'Bom';
  static const statusWarning = 'Atenção';
  static const statusCritical = 'Crítico';
  
  // Tipos de Meta
  static const goalTypeSavings = 'Juntar dinheiro';
  static const goalTypeReduceExpense = 'Reduzir gastos';
  
  // Missões → Desafios
  static const missionsTitle = 'Desafios';
  static const activeChallenges = 'Desafios Ativos';
  static const completedChallenges = 'Desafios Concluídos';
  
  // XP → Pontos
  static const experiencePoints = 'Pontos';
  static const earnPoints = 'Ganhe pontos';
  
  // Transações
  static const incomeLabel = 'Entrou';
  static const expenseLabel = 'Saiu';
  static const balanceLabel = 'Sobrou';
  
  // Mensagens de Feedback
  static String savingsProgress(double percentage) => 
      'Você está guardando ${percentage.toStringAsFixed(0)}% da sua renda';
  
  static String goalProgress(double current, double target) =>
      'R\$ ${current.toStringAsFixed(2)} de R\$ ${target.toStringAsFixed(2)}';
  
  static String pointsEarned(int points) =>
      points == 1 ? '1 ponto ganho!' : '$points pontos ganhos!';
}
```

---

## 📝 Resumo de Implementação

### Prioridade Alta (Semana 1-2)
1. ✅ Implementar `FriendlyIndicatorCard` widget
2. ✅ Atualizar labels e textos usando `UserFriendlyStrings`
3. ✅ Criar `SimplifiedOnboardingView` no backend

### Prioridade Média (Semana 3-4)
1. ✅ Implementar `SimplifiedRootShell` (3 abas)
2. ✅ Criar `UnifiedHomePage`
3. ✅ Implementar `SimpleGoalWizard`

### Prioridade Baixa (Semana 5-8)
1. ✅ Refatorar sistema de metas no backend
2. ✅ Implementar analytics de UX
3. ✅ Criar testes de usabilidade

---

**Última Atualização**: Novembro 2025  
**Versão**: 1.0
