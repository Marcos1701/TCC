import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/services/gamification_service.dart';
import '../../../../core/services/mission_notification_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../missions/presentation/pages/missions_page.dart';
import '../../../missions/presentation/widgets/mission_details_sheet.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../transactions/presentation/widgets/payment_wizard.dart';
import '../../../transactions/presentation/widgets/transaction_action_selector.dart';
import '../../../transactions/presentation/widgets/transaction_wizard.dart';
import '../widgets/app_widgets.dart';
import 'finances_page.dart';

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
    _cacheManager.addListener(_onCacheInvalidated);
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.dashboard) && mounted) {
      _cacheManager.clearInvalidation(CacheType.dashboard);
      setState(() {
        _future = _repository.fetchDashboard().then((data) {
          if (mounted) {
            final session = SessionScope.of(context);
            session.updateProfile(data.profile);
            
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
    
    final session = SessionScope.of(context);
    session.updateProfile(data.profile);
    
    if (!mounted) return;
    await GamificationService.checkLevelUp(
      context: context,
      profile: data.profile,
    );
    
    if (!mounted) return;
    await GamificationService.checkMissionCompletions(
      context: context,
      missions: data.activeMissions,
    );
    
    if (!mounted) return;
    await MissionNotificationService.checkExpiringMissions(
      context: context,
      missions: data.activeMissions,
    );
    
    if (!mounted) return;
    await MissionNotificationService.checkNewMissions(
      context: context,
      missions: data.activeMissions,
    );
    
    if (mounted) {
      setState(() {
        _future = Future.value(data);
      });
    }
  }

  Future<void> _openTransactionSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionActionSelector(
        onActionSelected: (actionType) async {
          if (actionType == TransactionActionType.transaction) {
            _openTransactionWizard();
          } else {
            _openPaymentWizard();
          }
        },
      ),
    );
  }

  Future<void> _openTransactionWizard() async {
    final created = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TransactionWizard(),
    );

    if (created == null || !mounted) return;
    
    _cacheManager.invalidateAfterTransaction(action: 'transaction created');
    
    FeedbackService.showSuccess(
      context,
      '✅ Transação registrada! Confira seu progresso nos desafios.',
    );
  }

  Future<void> _openPaymentWizard() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const PaymentWizard(),
    );

    if (result == true && mounted) {
      _refresh();
    }
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _showMissionDetails(MissionProgressModel mission) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MissionDetailsSheet(
        missionProgress: mission,
        repository: _repository,
        onUpdate: _refresh,
        onStart: (_) async => _refresh(),
        onSkip: (_) async => _refresh(),
      ),
    );
  }

  Widget _buildViewAllChallengesButton(int count) {
    final theme = Theme.of(context);
    
    return Card(
      color: Colors.deepPurple[900]?.withOpacity(0.3),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openPage(const MissionsPage()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Ver todos os desafios ($count)',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  MonthSummaryCard(
                    summary: data.summary,
                    currency: _currency,
                  ),
                  const SizedBox(height: 16),
                  
                  if (data.activeMissions.isNotEmpty)
                    WeeklyChallengeCard(
                      mission: data.activeMissions.first,
                      onTap: () => _showMissionDetails(data.activeMissions.first),
                    ),
                  if (data.activeMissions.isNotEmpty)
                    const SizedBox(height: 16),
                  
                  if (data.activeMissions.length > 1)
                    _buildViewAllChallengesButton(data.activeMissions.length),
                  if (data.activeMissions.length > 1)
                    const SizedBox(height: 16),
                  
                  QuickActionsCard(
                    onAddTransaction: _openTransactionSheet,
                    onViewAnalysis: () => _openPage(const FinancesPage(initialTab: 1)),
                  ),
                  const SizedBox(height: 16),
                  
                  RecentTransactionsSection(
                    repository: _repository,
                    currency: _currency,
                    onViewAll: () => _openPage(const TransactionsPage()),
                  ),
                  const SizedBox(height: 16),
                  
                  RecentPaymentsCard(
                    repository: _repository,
                    currency: _currency,
                    onCreatePayment: _openPaymentWizard,
                    onViewAll: () => _openPage(const TransactionsPage()),
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

