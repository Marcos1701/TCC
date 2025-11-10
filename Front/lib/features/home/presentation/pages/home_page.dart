import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/services/gamification_service.dart';
import '../../../../core/services/mission_notification_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../leaderboard/presentation/pages/leaderboard_page.dart';
import '../../../missions/presentation/pages/missions_page.dart';
import '../../../missions/presentation/widgets/mission_details_sheet.dart';
import '../../../progress/presentation/pages/progress_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../transactions/presentation/pages/expense_payment_page.dart';
import '../../../transactions/presentation/widgets/register_transaction_sheet.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repository = FinanceRepository();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _cacheManager = CacheManager();
  late Future<DashboardData> _future = _repository.fetchDashboard();

  @override
  void initState() {
    super.initState();
    // Escuta mudanças no cache para atualizar automaticamente
    _cacheManager.addListener(_onCacheInvalidated);
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    // Recarrega dados quando o cache é invalidado
    if (_cacheManager.isInvalidated(CacheType.dashboard) && mounted) {
      _cacheManager.clearInvalidation(CacheType.dashboard);
      // Força o recarregamento imediato
      setState(() {
        _future = _repository.fetchDashboard().then((data) {
          if (mounted) {
            final session = SessionScope.of(context);
            session.updateProfile(data.profile);
            
            // Verificar celebrações de gamificação em background
            GamificationService.checkLevelUp(
              context: context,
              profile: data.profile,
            );
            
            GamificationService.checkMissionCompletions(
              context: context,
              missions: data.activeMissions,
            );
            
            MissionNotificationService.checkExpiringMissions(
              context: context,
              missions: data.activeMissions,
            );
            
            MissionNotificationService.checkNewMissions(
              context: context,
              missions: data.activeMissions,
            );
          }
          return data;
        });
      });
    }
  }

  Future<void> _refresh() async {
    final data = await _repository.fetchDashboard();
    if (!mounted) return;
    
    // Atualizar sessão com o profile do dashboard (evita requisição extra)
    final session = SessionScope.of(context);
    session.updateProfile(data.profile);
    
    // Verificar celebrações de gamificação
    await GamificationService.checkLevelUp(
      context: context,
      profile: data.profile,
    );
    
    if (!context.mounted) return;
    await GamificationService.checkMissionCompletions(
      context: context,
      missions: data.activeMissions,
    );
    
    // Verificar missões próximas de expirar
    if (!context.mounted) return;
    await MissionNotificationService.checkExpiringMissions(
      context: context,
      missions: data.activeMissions,
    );
    
    // Verificar novas missões
    if (!context.mounted) return;
    await MissionNotificationService.checkNewMissions(
      context: context,
      missions: data.activeMissions,
    );
    
    // Atualiza o estado DEPOIS de todo trabalho assíncrono
    if (mounted) {
      setState(() {
        _future = Future.value(data);
      });
    }
  }

  Future<void> _openTransactionSheet() async {
    final created = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegisterTransactionSheet(
        repository: _repository,
      ),
    );

    if (created == null || !mounted) return;
    
    // Invalida cache globalmente após criar transação
    _cacheManager.invalidateAfterTransaction(action: 'transaction created');
    
    // Mostrar feedback de sucesso
    FeedbackService.showSuccess(
      context,
      '✅ Transação registrada! Confira seu progresso nas missões.',
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.session?.user;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet, size: 24),
            const SizedBox(width: 8),
            Text(
              'GenApp',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Configurações',
            onPressed: () => _openPage(const SettingsPage()),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.white),
            tooltip: 'Ranking',
            onPressed: () => _openPage(const LeaderboardPage()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openTransactionSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                  children: [
                    Text(
                      'Não foi possível carregar o painel agora.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                children: [
                  _HomeSummaryCard(
                    userName: user?.name ?? 'Bem-vindo',
                    profile: data.profile,
                    summary: data.summary,
                    currency: _currency,
                    onProfileTap: () => _openPage(const SettingsPage()),
                    onProgressTap: () => _openPage(const ProgressPage()),
                    onTransactionsTap: () =>
                        _openPage(const TransactionsPage()),
                  ),
                  const SizedBox(height: 24),
                  // Gráfico de Evolução do Saldo
                  _BalanceEvolutionCard(
                    profile: data.profile,
                    summary: data.summary,
                    currency: _currency,
                    repository: _repository,
                  ),
                  const SizedBox(height: 24),
                  // Histórico de Transações
                  _TransactionHistorySection(
                    repository: _repository,
                    currency: _currency,
                    onViewAll: () => _openPage(const TransactionsPage()),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Missões em Andamento',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openPage(const MissionsPage()),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('Ver Mais'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MissionSection(
                    active: data.activeMissions,
                    repository: _repository,
                    onRefresh: _refresh,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({
    required this.userName,
    required this.profile,
    required this.summary,
    required this.currency,
    required this.onProfileTap,
    required this.onProgressTap,
    required this.onTransactionsTap,
  });

  final String userName;
  final ProfileModel profile;
  final SummaryMetrics summary;
  final NumberFormat currency;
  final VoidCallback onProfileTap;
  final VoidCallback onProgressTap;
  final VoidCallback onTransactionsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final saldo = summary.totalIncome - summary.totalExpense - summary.debtPayments;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com foto e pontuação
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Nível ${profile.level}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'XP Atual',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${profile.experiencePoints} pts',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Saldo principal
          Row(
            children: [
              Text(
                'Saldo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showBalanceExplanation(context, summary, currency),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            currency.format(saldo),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 20),
          
          // Cards de Receitas e Despesas
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A5E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.arrow_upward_rounded,
                            color: AppColors.support,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Receitas',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currency.format(summary.totalIncome),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A5E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.arrow_downward_rounded,
                            color: AppColors.alert,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Despesas',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currency.format(summary.totalExpense),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Card de Pagamentos
          if (summary.debtPayments > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A5E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.highlight,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pagamentos:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    currency.format(summary.debtPayments),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.highlight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          
          // Botões de ação
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.person_outline,
                  label: 'Perfil',
                  onTap: onProfileTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.payment,
                  label: 'Pagar Despesa',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExpensePaymentPage()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.flag_outlined,
                  label: 'Metas',
                  onTap: onProgressTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transações',
                  onTap: onTransactionsTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  static void _showBalanceExplanation(
    BuildContext context,
    SummaryMetrics summary,
    NumberFormat currency,
  ) {
    final saldo = summary.totalIncome - summary.totalExpense - summary.debtPayments;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calculate_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Como o Saldo é Calculado?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _BalanceCalculationRow(
                    label: 'Receitas',
                    value: currency.format(summary.totalIncome),
                    color: AppColors.support,
                    icon: Icons.add,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Colors.white12, height: 1),
                  ),
                  _BalanceCalculationRow(
                    label: 'Despesas',
                    value: currency.format(summary.totalExpense),
                    color: AppColors.alert,
                    icon: Icons.remove,
                  ),
                  if (summary.debtPayments > 0) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: Colors.white12, height: 1),
                    ),
                    _BalanceCalculationRow(
                      label: 'Pagamentos',
                      value: currency.format(summary.debtPayments),
                      color: AppColors.highlight,
                      icon: Icons.remove,
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Colors.white24, height: 2, thickness: 2),
                  ),
                  _BalanceCalculationRow(
                    label: 'Saldo Final',
                    value: currency.format(saldo),
                    color: saldo >= 0 ? AppColors.support : AppColors.alert,
                    icon: Icons.account_balance_wallet,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summary.debtPayments > 0
                          ? 'Os pagamentos são valores vinculados de receitas para quitar despesas, reduzindo seu saldo disponível.'
                          : 'Saldo = Receitas - Despesas. Use "Pagar Despesa" para vincular receitas a despesas pendentes.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _BalanceCalculationRow extends StatelessWidget {
  const _BalanceCalculationRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionSection extends StatelessWidget {
  const _MissionSection({
    required this.active,
    required this.repository,
    required this.onRefresh,
  });

  final List<MissionProgressModel> active;
  final FinanceRepository repository;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty) {
      return const _EmptySection(
        message: 'Sem missões ativas no momento.\nContinue registrando transações para receber novas missões!',
      );
    }

    return Column(
      children: [
        for (final mission in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () async {
                await showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => MissionDetailsSheet(
                    missionProgress: mission,
                    repository: repository,
                    onUpdate: onRefresh,
                  ),
                );
              },
              child: _MissionTile(mission: mission),
            ),
          ),
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission});

  final MissionProgressModel mission;

  /// Retorna cor baseada no tipo de missão
  Color _getMissionTypeColor(String type) {
    switch (type) {
      case 'ONBOARDING':
        return const Color(0xFF9C27B0); // Roxo
      case 'TPS_IMPROVEMENT':
        return const Color(0xFF4CAF50); // Verde
      case 'RDR_REDUCTION':
        return const Color(0xFFF44336); // Vermelho
      case 'ILI_BUILDING':
        return const Color(0xFF2196F3); // Azul
      case 'ADVANCED':
        return const Color(0xFFFF9800); // Laranja
      default:
        return const Color(0xFF607D8B); // Cinza
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final progressValue = (mission.progress / 100).clamp(0.0, 1.0);
    
    // Calcular dias restantes
    String deadlineText = '-';
    Color deadlineColor = Colors.grey[400]!;
    IconData deadlineIcon = Icons.timer_outlined;
    
    if (mission.startedAt != null && mission.mission.durationDays > 0) {
      final endDate = mission.startedAt!.add(
        Duration(days: mission.mission.durationDays),
      );
      final daysRemaining = endDate.difference(DateTime.now()).inDays;
      
      // Formatar texto baseado nos dias restantes
      if (daysRemaining < 0) {
        deadlineText = 'Expirada';
        deadlineColor = AppColors.alert;
        deadlineIcon = Icons.error_outline;
      } else if (daysRemaining == 0) {
        deadlineText = 'Último dia';
        deadlineColor = AppColors.highlight;
        deadlineIcon = Icons.warning_amber_outlined;
      } else if (daysRemaining <= 3) {
        deadlineText = '$daysRemaining dias restantes';
        deadlineColor = AppColors.highlight;
        deadlineIcon = Icons.warning_amber_outlined;
      } else {
        deadlineText = '$daysRemaining dias restantes';
        deadlineColor = Colors.grey[400]!;
        deadlineIcon = Icons.timer_outlined;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge do tipo de missão
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getMissionTypeColor(mission.mission.missionType),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  mission.mission.missionTypeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              // Indicador de prazo
              Row(
                children: [
                  Icon(
                    deadlineIcon,
                    color: deadlineColor,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    deadlineText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: deadlineColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mission.mission.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mission.mission.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${mission.progress.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (mission.progress >= 100) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.support,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Missão concluída! +${mission.mission.rewardPoints} XP',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.support,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card com gráfico de evolução do saldo
class _BalanceEvolutionCard extends StatefulWidget {
  const _BalanceEvolutionCard({
    required this.profile,
    required this.summary,
    required this.currency,
    required this.repository,
  });

  final ProfileModel profile;
  final SummaryMetrics summary;
  final NumberFormat currency;
  final FinanceRepository repository;

  @override
  State<_BalanceEvolutionCard> createState() => _BalanceEvolutionCardState();
}

class _BalanceEvolutionCardState extends State<_BalanceEvolutionCard> {
  int _selectedPeriod = 7; // Padrão: 7 dias
  List<TransactionModel>? _transactions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await widget.repository.fetchTransactions();
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<FlSpot> _calculateBalanceEvolution() {
    if (_transactions == null || _transactions!.isEmpty) {
      // Retorna dados zerados se não houver transações
      return List.generate(_selectedPeriod, (index) => FlSpot(index.toDouble(), 0));
    }

    // Data final (hoje)
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    
    // Data inicial baseada no período selecionado
    final startDate = endDate.subtract(Duration(days: _selectedPeriod - 1));

    // Filtra transações dentro do período
    final relevantTransactions = _transactions!.where((t) {
      final txDate = DateTime(t.date.year, t.date.month, t.date.day);
      return !txDate.isBefore(startDate) && !txDate.isAfter(endDate);
    }).toList();

    // Ordena por data
    relevantTransactions.sort((a, b) => a.date.compareTo(b.date));

    // Calcula saldo inicial (todas as transações antes do período)
    double initialBalance = 0;
    for (final tx in _transactions!) {
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (txDate.isBefore(startDate)) {
        if (tx.type == 'INCOME') {
          initialBalance += tx.amount;
        } else {
          initialBalance -= tx.amount;
        }
      }
    }

    // Gera pontos do gráfico
    final spots = <FlSpot>[];
    double currentBalance = initialBalance;

    for (int i = 0; i < _selectedPeriod; i++) {
      final currentDate = startDate.add(Duration(days: i));
      
      // Soma transações do dia atual
      for (final tx in relevantTransactions) {
        final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
        if (txDate.isAtSameMomentAs(currentDate)) {
          if (tx.type == 'INCOME') {
            currentBalance += tx.amount;
          } else {
            currentBalance -= tx.amount;
          }
        }
      }
      
      spots.add(FlSpot(i.toDouble(), currentBalance));
    }

    return spots;
  }

  String _getBottomTitle(int index) {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = endDate.subtract(Duration(days: _selectedPeriod - 1));
    final date = startDate.add(Duration(days: index));

    if (_selectedPeriod == 7) {
      // Para 7 dias, mostra inicial do dia da semana
      const days = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
      return days[date.weekday % 7];
    } else if (_selectedPeriod == 15) {
      // Para 15 dias, mostra dia do mês a cada 3 dias (0, 3, 6, 9, 12, 14)
      if (index == 0 || index % 3 == 0 || index == _selectedPeriod - 1) {
        return '${date.day}';
      }
      return '';
    } else {
      // Para 30 dias, mostra dia do mês em intervalos estratégicos (0, 6, 12, 18, 24, 29)
      if (index == 0 || index % 6 == 0 || index == _selectedPeriod - 1) {
        return '${date.day}';
      }
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.cardRadius,
          boxShadow: tokens.mediumShadow,
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final spots = _calculateBalanceEvolution();
    
    // Calcula valores para o eixo Y com margem adequada
    var maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    var minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    
    // Garante que maxY e minY não sejam iguais e adiciona margem
    if (maxY == minY) {
      if (maxY == 0) {
        maxY = 100;
        minY = -100;
      } else if (maxY > 0) {
        minY = 0;
        maxY = maxY * 1.2;
      } else {
        minY = minY * 1.2;
        maxY = 0;
      }
    } else {
      // Adiciona margem de 10% em cada extremo
      final range = maxY - minY;
      maxY = maxY + (range * 0.1);
      minY = minY - (range * 0.1);
    }
    
    // Calcula a tendência (evolução percentual do início ao fim)
    final initialBalance = spots.first.y;
    final finalBalance = spots.last.y;
    final trend = finalBalance - initialBalance;
    final trendPercent = initialBalance != 0 
        ? (trend / initialBalance.abs()) * 100 
        : (finalBalance != 0 ? (finalBalance > 0 ? 100.0 : -100.0) : 0.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evolução do Saldo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Últimos $_selectedPeriod dias',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Indicador de tendência
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: trend >= 0 
                      ? AppColors.support.withOpacity(0.2)
                      : AppColors.alert.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      trend >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: trend >= 0 ? AppColors.support : AppColors.alert,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trendPercent >= 0 ? '+' : ''}${trendPercent.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: trend >= 0 ? AppColors.support : AppColors.alert,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Seletor de período
          Row(
            children: [
              _PeriodChip(
                label: '7d',
                isSelected: _selectedPeriod == 7,
                onTap: () {
                  setState(() => _selectedPeriod = 7);
                },
              ),
              const SizedBox(width: 8),
              _PeriodChip(
                label: '15d',
                isSelected: _selectedPeriod == 15,
                onTap: () {
                  setState(() => _selectedPeriod = 15);
                },
              ),
              const SizedBox(width: 8),
              _PeriodChip(
                label: '30d',
                isSelected: _selectedPeriod == 30,
                onTap: () {
                  setState(() => _selectedPeriod = 30);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        // Mostra pontos maiores apenas em intervalos para não poluir
                        final showLargeDot = _selectedPeriod == 7 || 
                                           (_selectedPeriod == 15 && index % 3 == 0) ||
                                           (_selectedPeriod == 30 && index % 6 == 0) ||
                                           index == 0 ||
                                           index == spots.length - 1;
                        
                        return FlDotCirclePainter(
                          radius: showLargeDot ? 4 : 2,
                          color: AppColors.primary,
                          strokeWidth: showLargeDot ? 2 : 1,
                          strokeColor: const Color(0xFF1E1E1E),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.3),
                          AppColors.primary.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        // Só mostra labels nos índices que têm texto
                        if (value < 0 || value >= _selectedPeriod) {
                          return const SizedBox();
                        }
                        
                        final title = _getBottomTitle(value.toInt());
                        if (title.isEmpty) return const SizedBox();
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[800]!.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.black87,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        // Calcula a data do ponto
                        final now = DateTime.now();
                        final endDate = DateTime(now.year, now.month, now.day);
                        final startDate = endDate.subtract(Duration(days: _selectedPeriod - 1));
                        final pointDate = startDate.add(Duration(days: spot.x.toInt()));
                        
                        return LineTooltipItem(
                          '${pointDate.day}/${pointDate.month}\n${widget.currency.format(spot.y)}',
                          theme.textTheme.bodySmall!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: AppColors.primary.withOpacity(0.5),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: AppColors.primary,
                              strokeWidth: 3,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip para seleção de período
class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.2)
              : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.grey[400],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Seção com histórico das últimas transações
class _TransactionHistorySection extends StatefulWidget {
  const _TransactionHistorySection({
    required this.repository,
    required this.currency,
    required this.onViewAll,
  });

  final FinanceRepository repository;
  final NumberFormat currency;
  final VoidCallback onViewAll;

  @override
  State<_TransactionHistorySection> createState() =>
      _TransactionHistorySectionState();
}

class _TransactionHistorySectionState
    extends State<_TransactionHistorySection> {
  final _cacheManager = CacheManager();
  late Future<List<TransactionModel>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = widget.repository.fetchTransactions();
    _cacheManager.addListener(_onCacheInvalidated);
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.transactions) && mounted) {
      setState(() {
        _transactionsFuture = widget.repository.fetchTransactions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Últimas Transações',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            TextButton(
              onPressed: widget.onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Ver Todas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<TransactionModel>>(
          future: _transactionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: tokens.cardRadius,
                ),
                child: Center(
                  child: Text(
                    'Erro ao carregar transações',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              );
            }

            final transactions = snapshot.data ?? [];
            if (transactions.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: tokens.cardRadius,
                  boxShadow: tokens.mediumShadow,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma transação registrada',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Adicione sua primeira transação',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Pegar as 5 transações mais recentes
            final recentTransactions = transactions.take(5).toList();

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: tokens.cardRadius,
                boxShadow: tokens.mediumShadow,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTransactions.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey[800],
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final transaction = recentTransactions[index];
                  return GestureDetector(
                    onTap: () async {
                      await showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => TransactionDetailsSheet(
                          transaction: transaction,
                          repository: widget.repository,
                          onUpdate: () {
                            setState(() {
                              _transactionsFuture = widget.repository.fetchTransactions();
                            });
                          },
                        ),
                      );
                    },
                    child: _TransactionTile(
                      transaction: transaction,
                      currency: widget.currency,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.currency,
  });

  final TransactionModel transaction;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determina o tipo de transação e cores correspondentes
    final isIncome = transaction.type.toUpperCase() == 'INCOME';
    final isPayment = transaction.type.toUpperCase() == 'DEBT_PAYMENT';
    
    // Define cores baseadas no tipo
    Color color;
    String prefix;
    if (isIncome) {
      color = AppColors.support; // Verde para receitas
      prefix = '+';
    } else if (isPayment) {
      color = AppColors.highlight; // Laranja para pagamentos
      prefix = '-';
    } else {
      color = AppColors.alert; // Vermelho para despesas
      prefix = '-';
    }
    
    final icon = _getCategoryIcon(transaction.category?.name, transaction.type);
    
    // Obter cor da categoria (se disponível)
    final categoryColor = _parseCategoryColor(transaction.category?.color);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          // Borda com a cor da categoria
          border: categoryColor != null
              ? Border.all(
                  color: categoryColor.withOpacity(0.5),
                  width: 2,
                )
              : null,
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
      title: Text(
        transaction.description,
        style: theme.textTheme.titleSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (transaction.category != null) ...[
                  // Indicador colorido da categoria
                  if (categoryColor != null) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: categoryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      transaction.category!.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    ' • ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                Text(
                  DateFormat('dd/MM/yyyy').format(transaction.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (transaction.isRecurring) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.repeat,
              color: Colors.grey[600],
              size: 14,
            ),
          ],
        ],
      ),
      trailing: Text(
        '$prefix ${currency.format(transaction.amount)}',
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? categoryName, String transactionType) {
    if (categoryName == null) {
      // Ícones padrão por tipo de transação
      switch (transactionType.toUpperCase()) {
        case 'INCOME':
          return Icons.arrow_upward;
        case 'DEBT_PAYMENT':
          return Icons.payment;
        case 'EXPENSE':
        default:
          return Icons.arrow_downward;
      }
    }

    // Mapeia categorias para ícones
    final categoryIconMap = {
      'Alimentação': Icons.restaurant,
      'Transporte': Icons.directions_car,
      'Moradia': Icons.home,
      'Saúde': Icons.local_hospital,
      'Educação': Icons.school,
      'Lazer': Icons.movie,
      'Compras': Icons.shopping_cart,
      'Salário': Icons.work,
      'Investimentos': Icons.trending_up,
      'Freelance': Icons.attach_money,
      'Cartão de Crédito': Icons.credit_card,
      'Contas': Icons.receipt_long,
      'Outros': Icons.category,
    };

    return categoryIconMap[categoryName] ?? _getDefaultIcon(transactionType);
  }

  IconData _getDefaultIcon(String transactionType) {
    switch (transactionType.toUpperCase()) {
      case 'INCOME':
        return Icons.arrow_upward;
      case 'DEBT_PAYMENT':
        return Icons.payment;
      case 'EXPENSE':
      default:
        return Icons.arrow_downward;
    }
  }
  
  /// Parse a cor da categoria do formato HEX (#RRGGBB)
  Color? _parseCategoryColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return null;
    try {
      final hexColor = colorString.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
    } catch (e) {
      // Retorna null se falhar ao parsear
    }
    return null;
  }
}
