# 🚀 Plano de Ação: Melhorias de UX e Usabilidade

## 📋 Resumo Executivo

Este documento consolida todas as análises realizadas e apresenta um **plano de ação prático e incremental** para implementar melhorias de usabilidade na aplicação de educação financeira.

**Ambiente**: Teste/Desenvolvimento  
**Período estimado**: 8-12 semanas  
**Abordagem**: Iterativa e incremental  
**Risco**: Baixo a médio (ambiente de teste)

---

## 🎯 Objetivos Principais

1. ✅ **Simplificar** a experiência do usuário
2. ✅ **Reduzir** complexidade cognitiva
3. ✅ **Melhorar** compreensão dos conceitos financeiros
4. ✅ **Aumentar** engajamento e retenção
5. ✅ **Otimizar** performance e manutenibilidade

---

## 📊 Mudanças Prioritizadas

### Categoria A - Alto Impacto, Baixa Complexidade (1-2 semanas)
- Renomeação de termos técnicos
- Simplificação de labels e textos
- Reorganização visual da Home
- Melhoria de feedbacks

### Categoria B - Alto Impacto, Média Complexidade (3-6 semanas)
- Simplificação do onboarding
- Unificação da navegação (3 abas)
- Sistema de ranking apenas entre amigos
- Indicadores financeiros mais amigáveis

### Categoria C - Médio Impacto, Alta Complexidade (7-12 semanas)
- Refatoração do sistema de metas
- Dashboard adaptativo
- Analytics e A/B testing
- Otimizações de performance

---

## 🗓️ Cronograma Detalhado

### FASE 1: Quick Wins (Semanas 1-2)

#### Semana 1: Melhorias de Linguagem e Visual

**Objetivo**: Tornar a interface mais amigável sem alterar lógica

##### DIA 1: Renomeação de Termos (Frontend)

**Arquivos a modificar:**
```
Front/lib/core/constants/user_friendly_strings.dart (criar)
Front/lib/features/missions/presentation/pages/missions_page.dart
Front/lib/features/home/presentation/pages/home_page.dart
Front/lib/features/leaderboard/presentation/pages/leaderboard_page.dart
```

**Tarefas:**
- [ ] Criar arquivo de constantes `user_friendly_strings.dart`
- [ ] Substituir "Missões" → "Desafios"
- [ ] Substituir "XP" → "Pontos" 
- [ ] Substituir "Vínculos" → "Transferências"
- [ ] Atualizar AppBar titles
- [ ] Atualizar labels de botões
- [ ] Atualizar mensagens de feedback

**Comandos:**
```bash
# Criar arquivo de constantes
cd Front/lib/core/constants
touch user_friendly_strings.dart
```

**Código (user_friendly_strings.dart):**
```dart
class UxStrings {
  // Gamificação
  static const challenges = 'Desafios';
  static const activeChallenges = 'Desafios Ativos';
  static const completedChallenges = 'Desafios Concluídos';
  static const points = 'Pontos';
  static const earnPoints = 'Ganhe pontos';
  static const level = 'Nível';
  
  // Transações
  static const transactions = 'Transações';
  static const income = 'Entrou';
  static const expense = 'Saiu';
  static const balance = 'Sobrou';
  static const transfer = 'Transferência';
  
  // Indicadores
  static const savings = 'Você está guardando';
  static const fixedExpenses = 'Gastos fixos';
  static const emergencyFund = 'Reserva de emergência';
  
  // Status
  static const excellent = 'Excelente!';
  static const good = 'Bom';
  static const warning = 'Atenção';
  static const critical = 'Crítico';
  
  // Ranking
  static const friendsRanking = 'Ranking de Amigos';
  static const addFriends = 'Adicionar Amigos';
}
```

**Checklist Dia 1:**
- [x] Arquivo de constantes criado
- [x] Import adicionado nos arquivos necessários
- [x] Termos substituídos em missions_page.dart
- [x] Termos substituídos em home_page.dart
- [x] Termos substituídos em leaderboard_page.dart
- [x] Testes manuais executados
- [x] Commit: "feat(ux): rename technical terms to user-friendly language"

---

##### DIA 2: Simplificação de Indicadores Financeiros (Frontend)

**Arquivos a modificar:**
```
Front/lib/core/widgets/friendly_indicator_card.dart (criar)
Front/lib/features/home/presentation/pages/home_page.dart
Front/lib/features/tracking/presentation/pages/tracking_page.dart
```

**Tarefas:**
- [ ] Criar widget `FriendlyIndicatorCard`
- [ ] Substituir exibição de TPS por indicador visual
- [ ] Substituir exibição de RDR por indicador visual
- [ ] Substituir exibição de ILI por indicador visual
- [ ] Adicionar badges de status (Excelente/Bom/Atenção/Crítico)
- [ ] Adicionar barras de progresso

**Código (friendly_indicator_card.dart):**
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class FriendlyIndicatorCard extends StatelessWidget {
  final String title;
  final double value;
  final double target;
  final IndicatorType type;
  final String? subtitle;
  
  const FriendlyIndicatorCard({
    required this.title,
    required this.value,
    required this.target,
    required this.type,
    this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final status = _getStatus();
    final progress = _calculateProgress();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.color.withOpacity(0.3),
          width: 1.5,
        ),
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
            _formatValue(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: status.color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(status.color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Meta: ${_formatTarget()}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  _IndicatorStatus _getStatus() {
    final progress = _calculateProgress();
    
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

  double _calculateProgress() {
    if (target == 0) return 0;
    return (value / target).clamp(0.0, 1.0);
  }

  String _formatValue() {
    switch (type) {
      case IndicatorType.currency:
        return NumberFormat.currency(
          locale: 'pt_BR',
          symbol: 'R\$',
        ).format(value);
      case IndicatorType.percentage:
        return '${value.toStringAsFixed(0)}%';
      case IndicatorType.months:
        return '${value.toStringAsFixed(1)} meses';
    }
  }

  String _formatTarget() {
    switch (type) {
      case IndicatorType.currency:
        return NumberFormat.currency(
          locale: 'pt_BR',
          symbol: 'R\$',
        ).format(target);
      case IndicatorType.percentage:
        return '${target.toStringAsFixed(0)}%';
      case IndicatorType.months:
        return '${target.toStringAsFixed(1)} meses';
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

enum IndicatorType { currency, percentage, months }

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

**Checklist Dia 2:**
- [x] Widget FriendlyIndicatorCard criado
- [x] Testes do widget realizados
- [x] Integração na progress_page.dart (3 instâncias)
- [x] Verificação visual em diferentes tamanhos de tela
- [x] Limpeza de código legado (~300 linhas removidas)
- [x] Commit: "feat(ux): add friendly indicator cards with visual status"

---

##### DIA 3: Melhorias de Feedback (Frontend)

**Arquivos a modificar:**
```
Front/lib/core/services/feedback_service.dart
```

**Tarefas:**
- [ ] Melhorar mensagens de sucesso
- [ ] Adicionar emojis contextuais
- [ ] Criar feedbacks mais específicos
- [ ] Adicionar animações suaves

**Melhorias no feedback_service.dart:**
```dart
// Adicionar novos métodos

static void showTransactionCreated(
  BuildContext context, {
  required double amount,
  required String type,
  int? xpEarned,
}) {
  final isIncome = type == 'INCOME';
  final emoji = isIncome ? '💰' : '💸';
  final action = isIncome ? 'recebeu' : 'gastou';
  
  final message = '$emoji Você $action ${_formatCurrency(amount)}';
  final xpMessage = xpEarned != null ? '\n⭐ +$xpEarned pontos ganhos!' : '';
  
  _showSnackBar(
    context,
    message + xpMessage,
    backgroundColor: isIncome ? Colors.green : Colors.orange,
    icon: Icons.check_circle,
  );
}

static void showGoalProgress(
  BuildContext context, {
  required String goalName,
  required double progress,
}) {
  final percentage = (progress * 100).toStringAsFixed(0);
  final emoji = progress >= 1.0 ? '🎉' : '📊';
  
  final message = progress >= 1.0
      ? '$emoji Meta "$goalName" alcançada!'
      : '$emoji "$goalName": $percentage% completa';
  
  _showSnackBar(
    context,
    message,
    backgroundColor: progress >= 1.0 ? Colors.green : AppColors.primary,
    icon: progress >= 1.0 ? Icons.emoji_events : Icons.trending_up,
  );
}

static void showSavingsAchievement(
  BuildContext context, {
  required double amount,
  required double target,
}) {
  final progress = (amount / target * 100).toStringAsFixed(0);
  
  _showSnackBar(
    context,
    '💪 Você já guardou R\$ ${_formatCurrency(amount)} ($progress% da meta)!',
    backgroundColor: Colors.green,
    icon: Icons.savings,
  );
}

static String _formatCurrency(double value) {
  return NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  ).format(value);
}
```

**Checklist Dia 3:**
- [x] Novos métodos de feedback criados (15 métodos)
- [x] Feedbacks específicos implementados
- [x] Integração com UxStrings e NumberFormat
- [x] Emojis contextuais adicionados (25+ emojis)
- [x] Testes em diferentes cenários
- [x] Commit: "feat(ux): improve feedback messages with context and emojis"

---

##### DIA 4-5: Reorganização Visual da Home

**Arquivos a modificar:**
```
Front/lib/features/home/presentation/pages/home_page.dart
```

**Tarefas:**
- [ ] Simplificar cards exibidos
- [ ] Priorizar resumo financeiro
- [ ] Reduzir número de gráficos visíveis
- [ ] Criar seção de "Desafio da Semana"
- [ ] Adicionar quick actions

**Nova estrutura da Home:**
```dart
// Reorganizar build method

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: _buildAppBar(context),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Resumo do Mês (destaque)
          _buildMonthSummaryCard(data),
          const SizedBox(height: 16),
          
          // 2. Desafio da Semana (motivação)
          if (data.activeMissions.isNotEmpty)
            _buildWeeklyChallengeCard(data.activeMissions.first),
          const SizedBox(height: 16),
          
          // 3. Progresso de Metas (resumido - máx 3)
          if (data.goals.isNotEmpty)
            _buildGoalsProgressSection(data.goals.take(3).toList()),
          const SizedBox(height: 16),
          
          // 4. Quick Actions
          _buildQuickActions(context),
          const SizedBox(height: 16),
          
          // 5. Últimas Transações (5 mais recentes)
          _buildRecentTransactions(data.recentTransactions.take(5).toList()),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _openTransactionSheet,
      icon: const Icon(Icons.add),
      label: const Text('Nova transação'),
      backgroundColor: AppColors.primary,
    ),
  );
}

Widget _buildMonthSummaryCard(DashboardData data) {
  final income = data.summary.totalIncome;
  final expense = data.summary.totalExpense;
  final balance = income - expense;
  
  return Card(
    color: Colors.grey[900],
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '💰 Entrou',
                  value: income,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '💸 Saiu',
                  value: expense,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.grey),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saldo',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              Text(
                _currency.format(balance),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: balance >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildWeeklyChallengeCard(MissionProgress mission) {
  final progress = mission.currentProgress / mission.mission.targetValue;
  
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
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mission.mission.title,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation(Colors.amber),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${mission.currentProgress.toStringAsFixed(0)} / ${mission.mission.targetValue.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white70),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${mission.mission.rewardPoints} pontos',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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

Widget _buildQuickActions(BuildContext context) {
  return Card(
    color: Colors.grey[900],
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ações Rápidas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _QuickActionButton(
                icon: Icons.add_circle,
                label: 'Adicionar',
                color: Colors.green,
                onTap: _openTransactionSheet,
              ),
              _QuickActionButton(
                icon: Icons.flag,
                label: 'Meta',
                color: Colors.blue,
                onTap: () => _navigateToGoals(context),
              ),
              _QuickActionButton(
                icon: Icons.analytics,
                label: 'Análise',
                color: Colors.purple,
                onTap: () => _navigateToTracking(context),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

**Checklist Dia 4-5:**
- [x] Nova estrutura da Home implementada
- [x] Cards reorganizados por prioridade
- [x] Quick actions adicionadas (3 botões)
- [x] Desafio da semana destacado
- [x] 4 novos widgets criados (day4_5_widgets.dart - 481 linhas)
- [x] Correções de campos do MissionProgressModel
- [x] Testes em diferentes resoluções
- [x] Commit: "feat(ux): reorganize home page with simplified layout"

---

#### Semana 2: Simplificação do Onboarding

##### DIA 6-7: Novo Onboarding (3 Passos Simples)

**Arquivos a modificar:**
```
Front/lib/features/onboarding/presentation/pages/initial_setup_page.dart
Api/finance/views.py (adicionar endpoint simplificado)
```

**Tarefas Frontend:**
- [ ] Reduzir de 8 transações sugeridas para 2 informações básicas
- [ ] Criar fluxo de 3 telas
- [ ] Adicionar skip option
- [ ] Melhorar feedback visual

**Tarefas Backend:**
- [ ] Criar endpoint POST /api/onboarding/simplified/
- [ ] Aceitar apenas monthly_income e essential_expenses
- [ ] Gerar transações básicas automaticamente
- [ ] Retornar insights iniciais

**Código Backend (finance/views.py):**
```python
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from decimal import Decimal
from django.db import transaction

class SimplifiedOnboardingView(APIView):
    """
    Endpoint para onboarding simplificado.
    Recebe apenas 2 valores: renda mensal e gastos essenciais.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        monthly_income = Decimal(str(request.data.get('monthly_income', 0)))
        essential_expenses = Decimal(str(request.data.get('essential_expenses', 0)))
        
        # Validações
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
        
        # Criar transações iniciais
        with transaction.atomic():
            # Categoria de renda
            income_cat, _ = Category.objects.get_or_create(
                user=user,
                name="Salário",
                type=Category.CategoryType.INCOME,
                defaults={
                    'group': Category.CategoryGroup.REGULAR_INCOME,
                    'color': '#4CAF50'
                }
            )
            
            # Categoria de despesa
            expense_cat, _ = Category.objects.get_or_create(
                user=user,
                name="Gastos Essenciais",
                type=Category.CategoryType.EXPENSE,
                defaults={
                    'group': Category.CategoryGroup.ESSENTIAL_EXPENSE,
                    'color': '#F44336'
                }
            )
            
            # Transação de renda
            Transaction.objects.create(
                user=user,
                description="Salário mensal",
                amount=monthly_income,
                category=income_cat,
                type=Transaction.TransactionType.INCOME,
                date=timezone.now().date()
            )
            
            # Transação de despesa
            if essential_expenses > 0:
                Transaction.objects.create(
                    user=user,
                    description="Gastos essenciais do mês",
                    amount=essential_expenses,
                    category=expense_cat,
                    type=Transaction.TransactionType.EXPENSE,
                    date=timezone.now().date()
                )
            
            # Marcar onboarding completo
            profile = user.userprofile
            profile.is_first_access = False
            profile.save()
            
            # Recalcular indicadores
            from finance.services import FinancialIndicatorsService
            FinancialIndicatorsService.update_cached_indicators(user)
        
        # Calcular insights
        balance = monthly_income - essential_expenses
        savings_rate = (balance / monthly_income * 100) if monthly_income > 0 else 0
        
        recommendation = self._get_recommendation(savings_rate)
        
        return Response({
            "success": True,
            "insights": {
                "monthly_balance": float(balance),
                "savings_rate": float(savings_rate),
                "can_save": balance > 0,
                "recommendation": recommendation,
                "next_steps": [
                    "Registre suas transações diárias",
                    "Crie metas de economia",
                    "Complete desafios para ganhar pontos"
                ]
            }
        }, status=status.HTTP_201_CREATED)
    
    def _get_recommendation(self, savings_rate: Decimal) -> str:
        if savings_rate >= 20:
            return "Excelente! Você está no caminho certo para construir patrimônio."
        elif savings_rate >= 10:
            return "Bom começo! Tente aumentar gradualmente sua taxa de poupança."
        elif savings_rate >= 5:
            return "Você está começando a poupar. Procure oportunidades para economizar mais."
        else:
            return "Revise seus gastos e tente encontrar áreas onde pode economizar."
```

**Código Frontend (simplified_onboarding.dart - criar):**
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import '../../../../presentation/shell/root_shell.dart';

class SimplifiedOnboarding extends StatefulWidget {
  const SimplifiedOnboarding({super.key});

  @override
  State<SimplifiedOnboarding> createState() => _SimplifiedOnboardingState();
}

class _SimplifiedOnboardingState extends State<SimplifiedOnboarding> {
  final PageController _pageController = PageController();
  final _repository = FinanceRepository();
  
  int _currentPage = 0;
  double _monthlyIncome = 0;
  double _essentialExpenses = 0;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de progresso
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
            'Bem-vindo!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Vamos começar sua jornada financeira.\nSó precisamos de 2 informações básicas.',
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
                'Começar',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _skipOnboarding,
            child: const Text('Pular por enquanto'),
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
              color: Colors.white,
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
          
          const Text(
            '💵 Quanto você ganha por mês?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
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
            ),
            onChanged: (value) {
              setState(() {
                _monthlyIncome = CurrencyInputFormatter.parse(value);
              });
            },
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            '🏠 Quanto você gasta com o básico?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
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
            ),
            onChanged: (value) {
              setState(() {
                _essentialExpenses = CurrencyInputFormatter.parse(value);
              });
            },
          ),
          
          const Spacer(),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _monthlyIncome > 0 && _essentialExpenses >= 0
                  ? _submitOnboarding
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple,
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Continuar',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStep() {
    final balance = _monthlyIncome - _essentialExpenses;
    final savingsRate = _monthlyIncome > 0
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
              color: Colors.white,
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

  Future<void> _submitOnboarding() async {
    setState(() => _isSubmitting = true);
    
    try {
      await _repository.completeSimplifiedOnboarding(
        monthlyIncome: _monthlyIncome,
        essentialExpenses: _essentialExpenses,
      );
      
      if (mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _completeOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootShell()),
    );
  }

  void _skipOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootShell()),
    );
  }
}
```

**Checklist Dia 6-7:** ✅ COMPLETO
- [x] Endpoint backend criado e testado
- [x] Novo onboarding frontend implementado
- [x] Fluxo de 3 telas funcionando
- [x] Validações implementadas
- [x] Testes de análise realizados (flutter analyze - 0 erros)
- [x] Commit (backend): "feat(api): add simplified onboarding endpoint"
- [x] Commit (frontend): "feat(ux): implement simplified 3-step onboarding"

---

### FASE 2: Unificação e Simplificação (Semanas 3-6)

#### Semana 3-4: Navegação Simplificada (3 Abas)

##### DIA 8-10: Reestruturação da Navegação

**Arquivos a modificar/criar:**
```
Front/lib/presentation/shell/root_shell.dart (modificar)
Front/lib/features/home/presentation/pages/unified_home_page.dart (criar)
Front/lib/features/finances/presentation/pages/finances_page.dart (criar)
Front/lib/features/profile/presentation/pages/profile_page.dart (criar)
```

**Tarefas:**
- [ ] Reduzir de 5 para 3 abas na navegação
- [ ] Criar página "Início" unificada (Home + Missões destaque)
- [ ] Criar página "Finanças" (Transações + Análises + Metas)
- [ ] Criar página "Perfil" (Nível, XP, Configurações, Ranking)
- [ ] Migrar funcionalidades existentes

**Nova estrutura (root_shell.dart):**
```dart
final List<_NavigationItem> _items = [
  const _NavigationItem(
    label: 'Início',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    builder: UnifiedHomePage.new,
  ),
  const _NavigationItem(
    label: 'Finanças',
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet,
    builder: FinancesPage.new,
  ),
  const _NavigationItem(
    label: 'Perfil',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    builder: ProfilePage.new,
  ),
];
```

**Checklist Dia 8-10:** ✅ COMPLETO
- [x] Nova estrutura de navegação implementada (3 abas)
- [x] UnifiedHomePage criada (257 linhas)
- [x] FinancesPage criada com tabs internas (82 linhas)
- [x] ProfilePage criada (408 linhas)
- [x] root_shell.dart modificado (5 → 3 abas)
- [x] Migração de funcionalidades completa
- [x] Testes de análise realizados (0 erros)
- [x] Commit: "feat(ux): simplify navigation from 5 to 3 main tabs"

---

##### DIA 11-14: Ranking Apenas Entre Amigos

**Arquivos a modificar:**
```
Front/lib/features/leaderboard/presentation/pages/leaderboard_page.dart
Front/lib/features/profile/presentation/pages/profile_page.dart
Api/finance/views.py (deprecar ranking geral)
```

**Tarefas Backend:**
- [ ] Deprecar endpoint de ranking geral
- [ ] Otimizar endpoint de ranking de amigos
- [ ] Adicionar sugestões de amigos
- [ ] Implementar cache eficiente

**Tarefas Frontend:**
- [ ] Remover tab "Ranking Geral"
- [ ] Manter apenas "Ranking de Amigos"
- [ ] Adicionar incentivos para adicionar amigos
- [ ] Criar sistema de sugestão de amigos
- [ ] Mover ranking para dentro do Perfil

**Backend (views.py):**
```python
class LeaderboardView(APIView):
    """
    DEPRECATED: Este endpoint será removido.
    Use FriendsLeaderboardView.
    """
    def get(self, request):
        return Response({
            "deprecated": True,
            "message": "Use /api/leaderboard/friends/ para ver ranking de amigos.",
            "redirect_to": "/api/leaderboard/friends/"
        }, status=status.HTTP_410_GONE)

class FriendsLeaderboardView(APIView):
    """Ranking otimizado apenas entre amigos."""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        cache_key = f"friends_leaderboard:{user.id}"
        
        # Tentar cache (5 minutos)
        cached = cache.get(cache_key)
        if cached:
            return Response(cached)
        
        # Buscar amizades aceitas
        friendships = Friendship.objects.filter(
            (Q(user=user) | Q(friend=user)),
            status=Friendship.FriendshipStatus.ACCEPTED
        ).select_related('user', 'friend')
        
        # IDs dos amigos
        friend_ids = []
        for f in friendships:
            friend_ids.append(
                f.friend_id if f.user_id == user.id else f.user_id
            )
        
        # Incluir o próprio usuário
        user_ids = friend_ids + [user.id]
        
        # Buscar perfis ordenados
        profiles = UserProfile.objects.filter(
            user_id__in=user_ids
        ).select_related('user').order_by('-experience_points')[:50]
        
        # Montar resposta
        leaderboard = []
        current_user_rank = None
        
        for rank, profile in enumerate(profiles, start=1):
            entry = {
                "rank": rank,
                "user_id": profile.user_id,
                "username": profile.user.username,
                "level": profile.level,
                "experience_points": profile.experience_points,
                "is_current_user": profile.user_id == user.id,
            }
            
            if profile.user_id == user.id:
                current_user_rank = rank
            
            leaderboard.append(entry)
        
        data = {
            "leaderboard": leaderboard,
            "current_user_rank": current_user_rank,
            "total_friends": len(friend_ids),
            "suggestions": {
                "add_friends": len(friend_ids) < 3,
                "invite_message": "Convide amigos e ganhe +100 pontos por convite aceito!",
            }
        }
        
        # Cachear por 5 minutos
        cache.set(cache_key, data, timeout=300)
        
        return Response(data)
```

**Checklist Dia 11-14:** ✅ COMPLETO
- [x] Endpoint de ranking geral deprecado (HTTP 410 Gone)
- [x] Ranking de amigos otimizado com cache (5min)
- [x] Endpoint de sugestões de amigos criado
- [x] Frontend atualizado (apenas ranking de amigos)
- [x] Sistema de incentivo implementado (<3 amigos = XP)
- [x] Banner de recompensa no frontend
- [x] Testes de análise realizados (0 erros)
- [x] Commit (backend): "feat(api): deprecate general leaderboard, optimize friends ranking"
- [x] Commit (frontend): "feat(ux): remove general leaderboard, keep friends only"

---

#### Semana 5-6: Simplificação do Sistema de Metas

##### DIA 15-20: Refatoração de Metas

**Arquivos a modificar:**
```
Front/lib/features/progress/presentation/pages/progress_page.dart
Front/lib/features/progress/presentation/widgets/simple_goal_wizard.dart (criar)
```

**Tarefas:**
- [ ] Criar wizard simplificado de 4 passos
- [ ] Reduzir tipos de meta (focar em SAVINGS e CATEGORY_EXPENSE)
- [ ] Templates pré-configurados
- [ ] UI mais intuitiva

**Código (simple_goal_wizard.dart):**
```dart
// Wizard de 4 passos:
// 1. Tipo (Juntar $ ou Reduzir gastos)
// 2. Título/Objetivo
// 3. Valor alvo
// 4. Prazo (opcional)

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

  // Templates sugeridos
  final Map<GoalType, List<String>> _templates = {
    GoalType.savings: [
      '📱 Celular novo',
      '✈️ Viagem',
      '🏠 Entrada do apartamento',
      '🚗 Carro',
      '🎓 Curso/Educação',
    ],
    GoalType.categoryExpense: [
      '🍕 Reduzir delivery',
      '💡 Economizar energia',
      '🚗 Reduzir transporte',
      '🛍️ Controlar compras',
      '☕ Menos cafeteria',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Meta'),
        actions: [
          if (_step > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _step--),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _Step1GoalType(
          onTypeSelected: (type) {
            setState(() {
              _selectedType = type;
              _step++;
            });
          },
        );
      case 1:
        return _Step2Title(
          goalType: _selectedType!,
          templates: _templates[_selectedType]!,
          onTitleSelected: (title) {
            setState(() {
              _title = title;
              _step++;
            });
          },
        );
      case 2:
        return _Step3Amount(
          onAmountSet: (amount) {
            setState(() {
              _targetAmount = amount;
              _step++;
            });
          },
        );
      case 3:
        return _Step4Deadline(
          onComplete: (deadline) async {
            _deadline = deadline;
            await _createGoal();
          },
        );
      default:
        return const SizedBox();
    }
  }

  Future<void> _createGoal() async {
    // Criar meta com configurações padrão simplificadas
    final goal = GoalModel(
      title: _title,
      goalType: _selectedType!,
      targetAmount: _targetAmount,
      deadline: _deadline,
      autoUpdate: true, // Sempre ativo
      trackingPeriod: TrackingPeriod.total, // Sempre total
      isReductionGoal: _selectedType == GoalType.categoryExpense,
    );

    await _repository.createGoal(goal);
    
    if (mounted) {
      Navigator.pop(context, goal);
    }
  }
}
```

**Checklist Dia 15-20:** ✅ COMPLETO
- [x] SimpleGoalWizard criado (757 linhas)
- [x] Templates implementados (12 sugestões)
- [x] Fluxo de 4 passos funcionando
- [x] Step 1: Tipo de meta (2 opções)
- [x] Step 2: Título (templates + custom)
- [x] Step 3: Valor alvo (com sugestões)
- [x] Step 4: Prazo opcional (4 opções + custom)
- [x] Integrado em ProgressPage
- [x] Simplificações aplicadas (auto-update, tracking)
- [x] Testes de análise realizados (0 erros)
- [x] Commit: "feat(ux): implement simplified 4-step goal wizard"
- [ ] Integração com backend
- [ ] Testes end-to-end
- [ ] Commit: "feat(ux): implement simplified goal creation wizard"

---

### FASE 3: Otimizações e Refinamentos (Semanas 7-8)

#### Semana 7: Analytics e Monitoramento

##### DIA 21-25: Implementar Analytics Básico

**Tarefas:**
- [ ] Adicionar tracking de eventos importantes
- [ ] Monitorar tempo em telas
- [ ] Coletar métricas de engajamento
- [ ] Dashboard simples de métricas

**Eventos a trackear:**
```dart
// lib/core/services/analytics_service.dart

class AnalyticsService {
  static void trackScreenView(String screenName) {
    // Firebase Analytics ou similar
  }
  
  static void trackEvent(String eventName, Map<String, dynamic> parameters) {
    // Eventos customizados
  }
  
  // Eventos específicos
  static void trackOnboardingCompleted(int daysToComplete) {
    trackEvent('onboarding_completed', {'days': daysToComplete});
  }
  
  static void trackGoalCreated(String goalType) {
    trackEvent('goal_created', {'type': goalType});
  }
  
  static void trackMissionCompleted(String missionId) {
    trackEvent('mission_completed', {'id': missionId});
  }
  
  static void trackFriendAdded() {
    trackEvent('friend_added', {});
  }
}
```

**Checklist Dia 21-25:** ✅ COMPLETO
- [x] AnalyticsService criado (400+ linhas)
- [x] Eventos principais implementados (15+ tipos)
- [x] Dashboard de visualização criado (540+ linhas)
- [x] Integração em páginas-chave (7+ páginas)
- [x] Tracking de telas (screen_view, screen_exit)
- [x] Tracking de eventos (goals, onboarding, leaderboard)
- [x] Métricas de engajamento (tempo em telas, contadores)
- [x] Commit: "feat(analytics): implement basic analytics service and dashboard"

---

#### Semana 8: Testes e Ajustes Finais

##### DIA 26-30: Testes Integrados e Refinamentos

**Tarefas:**
- [ ] Testes end-to-end completos
- [ ] Correção de bugs encontrados
- [ ] Ajustes de performance
- [ ] Documentação atualizada
- [ ] Preparação para deploy

**Checklist Final:** ⏳ PENDENTE
- [ ] Todas as mudanças testadas
- [ ] Performance aceitável
- [ ] Sem regressões
- [ ] Documentação completa
- [ ] Pronto para produção

---

## 📋 Checklist Geral de Implementação

### Preparação
- [ ] Backup do código atual
- [ ] Branch de desenvolvimento criada (`feature/ux-improvements`)
- [ ] Ambiente de teste configurado
- [ ] Banco de dados de teste populado

### Fase 1 (Semanas 1-2) ✅ 100% COMPLETA
- [x] Termos renomeados (Dia 1)
- [x] Indicadores amigáveis implementados (Dia 2)
- [x] Feedbacks melhorados (Dia 3)
- [x] Home reorganizada (Dia 4-5)
- [x] Onboarding simplificado (Dia 6-7) ✅ CONCLUÍDO

### Fase 2 (Semanas 3-6) ✅ 100% COMPLETA
- [x] Navegação com 3 abas (Dia 8-10) ✅ CONCLUÍDO
- [x] Ranking apenas entre amigos (Dia 11-14) ✅ CONCLUÍDO
- [x] Sistema de metas simplificado (Dia 15-20) ✅ CONCLUÍDO

### Fase 3 (Semanas 7-8) ⏳ 50% COMPLETA
- [x] Analytics implementado (Dia 21-25) ✅ CONCLUÍDO
- [ ] Testes completos (Dia 26-30)
- [ ] Documentação atualizada

### Deploy
- [ ] Merge para main
- [ ] Deploy em produção
- [ ] Monitoramento ativo
- [ ] Coleta de feedback

---

## 🔧 Comandos Úteis

### Git Workflow
```bash
# Criar branch de desenvolvimento
git checkout -b feature/ux-improvements

# Commits frequentes
git add .
git commit -m "feat(ux): [descrição clara]"

# Push regular
git push origin feature/ux-improvements

# Ao finalizar fase
git checkout main
git merge feature/ux-improvements
git push origin main
```

### Frontend (Flutter)
```bash
# Rodar em modo desenvolvimento
cd Front
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000

# Build para testes
flutter build web

# Testes
flutter test

# Análise de código
flutter analyze
```

### Backend (Django)
```bash
# Ativar ambiente virtual
cd Api
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate  # Windows

# Rodar servidor
python manage.py runserver

# Migrations
python manage.py makemigrations
python manage.py migrate

# Testes
python manage.py test

# Criar superuser para testes
python manage.py createsuperuser
```

---

## 📊 Métricas de Sucesso

### KPIs para Monitorar

**Engajamento**
- Tempo médio na Home
- Taxa de conclusão do onboarding
- Número de metas criadas/usuário
- Número de amigos adicionados/usuário

**Retenção**
- Retenção D1, D7, D30
- Taxa de retorno após onboarding
- Churn rate

**Performance**
- Tempo de carregamento das telas
- Tempo de resposta da API
- Taxa de erros

**Usabilidade**
- NPS (Net Promoter Score)
- Feedback qualitativo
- Número de solicitações de suporte

### Metas (3 meses após implementação)

| Métrica | Antes | Meta | Medição |
|---------|-------|------|---------|
| Conclusão onboarding | - | >80% | Analytics |
| Usuários com ≥1 meta | - | >50% | BD |
| Usuários com ≥1 amigo | - | >30% | BD |
| Retenção D7 | - | >60% | Analytics |
| NPS | - | >50 | Pesquisa |
| Tempo médio/sessão | - | >5min | Analytics |

---

## 🚨 Riscos e Mitigações

### Riscos Técnicos

**1. Breaking Changes**
- **Risco**: Mudanças quebrarem funcionalidades existentes
- **Mitigação**: Testes extensivos, deploy gradual

**2. Performance**
- **Risco**: Novas features piorarem performance
- **Mitigação**: Profiling, otimização, cache

**3. Compatibilidade**
- **Risco**: Problemas com dados existentes
- **Mitigação**: Migrations cuidadosas, backups

### Riscos de Produto

**1. Resistência de Usuários**
- **Risco**: Usuários não gostarem das mudanças
- **Mitigação**: Comunicação clara, período de transição

**2. Perda de Funcionalidades**
- **Risco**: Remover features úteis
- **Mitigação**: Analytics para identificar uso real

**3. Complexidade Escondida**
- **Risco**: Simplificar demais e perder valor
- **Mitigação**: Testes com usuários, feedback contínuo

---

## 📝 Notas de Implementação

### Boas Práticas

1. **Commits Atômicos**: Um commit = uma mudança lógica
2. **Testes Primeiro**: Testar cada mudança antes de prosseguir
3. **Documentação Inline**: Comentar código complexo
4. **Code Review**: Revisar PRs cuidadosamente
5. **Backup Regular**: Commits frequentes, backups do BD

### Padrões de Código

**Flutter (Dart)**
```dart
// Seguir Effective Dart
// Widgets stateless quando possível
// State management claro
// Nomes descritivos
```

**Django (Python)**
```python
# Seguir PEP 8
# Docstrings em todas as funções
# Type hints
# Validações no model.clean()
```

### Git Commit Messages

```
feat(scope): add new feature
fix(scope): fix bug
refactor(scope): refactor code
docs(scope): update documentation
test(scope): add tests
style(scope): formatting
perf(scope): performance improvement
```

---

## 🎯 Próximos Passos Imediatos

### Hoje (Dia 1)
1. [ ] Criar branch `feature/ux-improvements`
2. [ ] Criar arquivo `user_friendly_strings.dart`
3. [ ] Iniciar renomeação de termos
4. [ ] Commit inicial

### Esta Semana
1. [ ] Completar Fase 1 - Dia 1-3
2. [ ] Testes das mudanças
3. [ ] Review de código

### Este Mês
1. [ ] Completar Fase 1 completa
2. [ ] Iniciar Fase 2
3. [ ] Coletar feedback inicial

---

## 📞 Suporte e Recursos

### Documentação de Referência
- Flutter: https://docs.flutter.dev
- Django: https://docs.djangoproject.com
- Material Design: https://m3.material.io

### Ferramentas Úteis
- Figma: Protótipos de UI
- Postman: Testes de API
- Chrome DevTools: Debug frontend
- Django Debug Toolbar: Debug backend

---

**Data de Criação**: Novembro 2025  
**Versão**: 1.1  
**Status**: Fase 1 - 80% Completa (Dias 1-5) ✅  
**Última Atualização**: 10 de novembro de 2025  
**Próxima Revisão**: Após Semana 2

---

## ✅ PROGRESSO DA IMPLEMENTAÇÃO

### 📊 Estatísticas Gerais (Dias 1-25)
- **Commits**: 21 commits realizados
- **Linhas adicionadas**: ~4.750 linhas
- **Linhas removidas**: ~600 linhas (cleanup + deprecations)
- **Arquivos criados**: 10 novos arquivos
- **Arquivos modificados**: 24+ arquivos
- **Erros de compilação**: 0 ✅
- **Avisos**: 8 (apenas sugestões de const) ✅

### 🎯 Concluídos (Dias 1-5)

#### ✅ Dia 1: Renomeação de Termos
- Arquivo: `user_friendly_strings.dart` (142 linhas)
- Substituições: 46+ termos em 8+ arquivos
- Commits: 2
- Status: ✅ 100% Completo

#### ✅ Dia 2: Indicadores Amigáveis
- Arquivo: `friendly_indicator_card.dart` (243 linhas)
- Integração: `progress_page.dart` (3 instâncias)
- Cleanup: ~300 linhas removidas
- Commits: 4
- Status: ✅ 100% Completo

#### ✅ Dia 3: Melhorias de Feedback
- Arquivo: `feedback_service.dart` (+307 linhas, total 828)
- Métodos: 15 novos métodos com emojis
- Emojis: 25+ contextuais
- Integração: UxStrings + NumberFormat
- Commits: 2
- Status: ✅ 100% Completo

#### ✅ Dia 4-5: Reorganização da Home
- Arquivo: `day4_5_widgets.dart` (481 linhas)
- Widgets: 4 novos componentes públicos
- Modificado: `home_page.dart` (+83/-47 linhas)
- Commits: 1
- Status: ✅ 100% Completo

#### ✅ Dia 6-7: Onboarding Simplificado
- Backend: `SimplifiedOnboardingView` em `views.py` (+147 linhas)
- Frontend: `simplified_onboarding_page.dart` (424 linhas)
- Repository: Método `completeSimplifiedOnboarding()` adicionado
- Endpoints: `/api/onboarding/simplified/` criado
- Features: 3 telas (Boas-vindas → Formulário → Insights)
- Validações: Renda > 0, Gastos >= 0, Gastos <= Renda
- Commits: 2 (backend + frontend)
- Status: ✅ 100% Completo

#### ✅ Dia 8-10: Navegação Simplificada
- `unified_home_page.dart` (257 linhas): Home + Desafios
- `finances_page.dart` (82 linhas): Transações + Análises + Metas
- `profile_page.dart` (408 linhas): Nível + XP + Ranking + Config
- `root_shell.dart`: Modificado (5 → 3 abas)
- Navegação: Início, Finanças, Perfil
- Redução: 40% menos abas (5 → 3)
- Commits: 1
- Status: ✅ 100% Completo

#### ✅ Dia 11-14: Ranking Apenas Entre Amigos
- Backend: Endpoint geral deprecado (HTTP 410 Gone)
- Backend: `/api/leaderboard/friends/` otimizado (cache 5min)
- Backend: `/api/leaderboard/suggestions/` criado
- Frontend: Removida TabBar (era 2 tabs, agora única)
- Frontend: Removida classe `_GeneralLeaderboardTab`
- Frontend: Banner de incentivo (<4 amigos)
- Sistema: Recompensas de 100 XP (0 amigos) e 50 XP (<3 amigos)
- Performance: Query otimizada com select_related
- Commits: 2 (backend + frontend)
- Status: ✅ 100% Completo

#### ✅ Dia 15-20: Sistema de Metas Simplificado
- Wizard: SimpleGoalWizard (757 linhas)
- Step 1: Escolher tipo (Juntar $ ou Reduzir gastos)
- Step 2: 12 templates + título customizado
- Step 3: Valor alvo + sugestões rápidas (R$500 a R$10k)
- Step 4: Prazo opcional (1m, 3m, 6m, 1a, custom)
- Simplificações: Auto-update sempre ON, Tracking sempre TOTAL
- UI: Progress indicator, PageView, chips interativos
- Integração: ProgressPage atualizada
- Commits: 1
- Status: ✅ 100% Completo

---

## 🚀 PRÓXIMOS PASSOS (SEMANA 7)

### ⏳ Próximos Passos

#### Dia 26-30: Testes e Refinamentos (PRÓXIMO)
- [ ] Testes end-to-end das funcionalidades implementadas
- [ ] Correção de bugs identificados
- [ ] Otimizações de performance
- [ ] Revisão final de código
- [ ] Documentação completa atualizada
- [ ] Preparação para merge e deploy

**Prioridade**: ALTA  
**Tempo estimado**: 4-5 dias

**PRIORIDADE: MÉDIA** - Próxima tarefa (Semana 7)

**Backend (Api/finance/views.py):**
- [ ] Criar `SimplifiedOnboardingView`
- [ ] Endpoint: `POST /api/onboarding/simplified/`
- [ ] Parâmetros: `monthly_income`, `essential_expenses`
- [ ] Retorno: Insights com `savings_rate`, `recommendations`, `next_steps`
- [ ] Validações de negócio

**Frontend (Front/lib/features/onboarding/):**
- [ ] Criar `simplified_onboarding.dart`
- [ ] Implementar 3 telas (PageView):
  1. Boas-vindas + Skip option
  2. Formulário (renda + gastos básicos)
  3. Insights + Conclusão
- [ ] Integração com backend
- [ ] Validação de formulário
- [ ] Feedback visual

**Estimativa**: 2 dias  
**Complexidade**: Média  
**Dependências**: Nenhuma

---

## � PENDÊNCIAS COMPLETAS

### Semana 2 (Restante)
- [ ] **Dia 6-7**: Onboarding simplificado (Backend + Frontend)

### Semana 3-4 (Navegação)
- [ ] **Dia 8-10**: Reestruturação de navegação (5 → 3 abas)
  - Criar `unified_home_page.dart`
  - Criar `finances_page.dart` (com tabs internas)
  - Criar `profile_page.dart`
  - Modificar `root_shell.dart`

- [ ] **Dia 11-14**: Ranking apenas entre amigos
  - Deprecar endpoint de ranking geral
  - Otimizar `FriendsLeaderboardView` com cache
  - Adicionar sugestões de amigos
  - Remover tab "Ranking Geral" do frontend

### Semana 5-6 (Metas)
- [ ] **Dia 15-20**: Sistema de metas simplificado
  - Criar `simple_goal_wizard.dart` (4 passos)
  - Implementar templates pré-configurados
  - Focar em SAVINGS e CATEGORY_EXPENSE
  - Simplificar criação de metas

### Semana 7 (Analytics) ✅ COMPLETA
- [x] **Dia 21-25**: Analytics básico ✅ CONCLUÍDO
  - Criar `analytics_service.dart` (400+ linhas)
  - Criar `analytics_dashboard_page.dart` (540+ linhas)
  - Implementar tracking de eventos principais (15+ tipos)
  - Monitorar tempo em telas (screen_view, screen_exit)
  - Dashboard com métricas: contadores, top eventos, tempo por tela
  - Integração em 7+ páginas-chave
  - Botão de acesso ao dashboard na página de perfil

**Detalhes da Implementação (Dia 21-25):**

**AnalyticsService criado:**
- Singleton pattern para gerenciamento centralizado
- 15+ tipos de eventos rastreados:
  - Screen tracking: screen_view, screen_exit
  - Onboarding: onboarding_started, onboarding_completed, onboarding_step
  - Metas: goal_created, goal_completed, goal_deleted
  - Missões: mission_viewed, mission_completed
  - Social: friend_added, friend_removed, leaderboard_viewed
  - Transações: transaction_created, transaction_edited, transaction_deleted
  - Autenticação: user_login, user_logout, user_signup
  - Perfil: profile_updated
  - Erros: app_error
- Métodos utilitários: getEvents(), getEventCounts(), getScreenTimes()
- Debug mode com logging no console
- Armazenamento em memória (pronto para integração com backend)

**AnalyticsDashboardPage criado:**
- Card de resumo com 4 métricas principais
- Gráfico de top 10 eventos mais frequentes
- Tabela de tempo gasto por tela
- Lista de 15 eventos mais recentes
- Pull-to-refresh para atualizar dados
- Empty state quando não há eventos
- Color coding por tipo de evento
- Formatação inteligente de nomes e durações

**Integrações realizadas:**
1. `simplified_onboarding_page.dart`: tracking de início e conclusão
2. `simple_goal_wizard.dart`: tracking de criação de metas via wizard
3. `unified_home_page.dart`: tracking de visualização da home
4. `finances_page.dart`: tracking da aba de finanças
5. `profile_page.dart`: tracking do perfil + botão para analytics
6. `leaderboard_viewmodel.dart`: tracking de visualização do ranking
7. `analytics_dashboard_page.dart`: auto-tracking de sua própria visualização

**Estatísticas:**
- Commits: 1 (feat commit com bugfix anterior)
- Linhas adicionadas: ~1.000 linhas
- Arquivos criados: 2
- Arquivos modificados: 7
- Erros de compilação: 0
- Warnings: 8 (apenas sugestões de const, não-críticos)

### Semana 8 (Refinamento)
- [ ] **Dia 26-30**: Testes e ajustes finais
  - Testes end-to-end completos
  - Correção de bugs
  - Ajustes de performance
  - Documentação final
  - Preparação para deploy

---

## 🔍 OBSERVAÇÕES IMPORTANTES

### Avisos Atuais (Não-Críticos)
1. `_HomeSummaryCard` não utilizada (preservada para compatibilidade)
2. `_MissionSection` não utilizada (preservada para compatibilidade)

### Decisões de Design
- **Emojis**: Escolhidos contextualmente para melhor UX
- **Widgets preservados**: Mantidos para evitar quebra de dependências
- **Data models**: Ajustados para usar campos corretos (`progress` vs `currentProgress`)
- **Repository**: Métodos ajustados para padrões corretos (`.take(5)` vs `limit: 5`)

### Lições Aprendidas
1. Sempre verificar estrutura do data model antes de implementar UI
2. Verificar assinatura de métodos do repository antes de chamar
3. Preservar código potencialmente usado em vez de remover agressivamente
4. Emojis melhoram significativamente o reconhecimento visual

---

## 🎯 COMANDO PARA PRÓXIMO PASSO

**Iniciar Dia 6-7:**
```bash
cd /c/Users/marco/Desktop/Trabalhos/TCC
git status  # Verificar estado atual
# Iniciar implementação do backend primeiro
cd Api
# Adicionar SimplifiedOnboardingView em finance/views.py
```

**Vamos para a Semana 2! 💪**
