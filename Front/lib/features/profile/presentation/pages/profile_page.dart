import 'package:flutter/material.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _repository = FinanceRepository();
  late Future<SummaryMetrics> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<SummaryMetrics> _loadSummary() async {
    final dashboard = await _repository.fetchDashboard();
    return dashboard.summary;
  }

  Future<void> _refresh() async {
    final future = _loadSummary();
    setState(() {
      _summaryFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile;
  final user = session.session?.user;
  final userEmail = user?.email;
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: FutureBuilder<SummaryMetrics>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                children: [
                  Text(
                    'Perfil e ajustes',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gerencie dados da conta e indicadores do GenApp.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: tokens.heroGradient,
                      borderRadius: tokens.sheetRadius,
                      boxShadow: tokens.deepShadow,
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: tokens.tileRadius,
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              child: const Icon(Icons.person,
                                  size: 36, color: Colors.white),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.name ?? 'Usuário',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (userEmail != null && userEmail.isNotEmpty)
                                    ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      userEmail,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (profile != null) ...[
                          const SizedBox(height: 20),
                          LinearProgressIndicator(
                            value:
                                profile.experiencePoints / profile.nextLevelThreshold,
                            minHeight: 8,
                            backgroundColor: Colors.white24,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nível ${profile.level} • ${profile.experiencePoints} / ${profile.nextLevelThreshold} XP',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildIndicatorsCard(snapshot, theme, tokens),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await SessionScope.of(context).logout();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Você saiu da conta.')),
                      );
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sair do GenApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.alert,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorsCard(
    AsyncSnapshot<SummaryMetrics> snapshot,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    Widget content;
    if (snapshot.connectionState == ConnectionState.waiting) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (snapshot.hasError) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Não foi possível carregar os indicadores agora.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _refresh(),
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    } else if (!snapshot.hasData) {
      content = Text(
        'Indicadores indisponíveis no momento.',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      );
    } else {
      content = _IndicatorHighlights(summary: snapshot.data!);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: tokens.cardRadius,
        border: Border.all(color: theme.dividerColor),
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Indicadores do mês',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: content,
          ),
        ],
      ),
    );
  }
}

class _IndicatorHighlights extends StatelessWidget {
  const _IndicatorHighlights({required this.summary});

  final SummaryMetrics summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _IndicatorPill(
        label: 'Poupança do mês',
        value: '${summary.tps.toStringAsFixed(0)}%',
        description: 'Quanto da meta de guardar já foi alcançado.',
        color: AppColors.primary,
        icon: Icons.savings_outlined,
      ),
      _IndicatorPill(
        label: 'Uso da renda',
        value: '${summary.rdr.toStringAsFixed(0)}%',
        description: 'Parcela da renda comprometida com contas.',
        color: AppColors.highlight,
        icon: Icons.pie_chart_outline,
      ),
      _IndicatorPill(
        label: 'Reserva imediata',
        value: summary.ili < 1
            ? '${summary.ili.toStringAsFixed(1)} mês'
            : '${summary.ili.toStringAsFixed(1)} meses',
        description: 'Tempo coberto pela reserva financeira.',
        color: AppColors.support,
        icon: Icons.health_and_safety_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 3
            : width >= 560
                ? 2
                : 1;
        final spacing = 12.0;
        final itemWidth =
            columns == 1 ? width : (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _IndicatorPill extends StatelessWidget {
  const _IndicatorPill({
    required this.label,
    required this.value,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String description;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
