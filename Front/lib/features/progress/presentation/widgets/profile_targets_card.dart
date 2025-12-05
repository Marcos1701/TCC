import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/models/profile.dart';
import '../../../../presentation/widgets/friendly_indicator_card.dart';

/// Card que exibe o progresso geral do usuario e indicadores alvo.
/// 
/// Mostra:
/// - Nivel atual e progresso para o proximo nivel
/// - Indicadores financeiros (TPS, RDR, ILI) com metas
class ProfileTargetsCard extends StatefulWidget {
  const ProfileTargetsCard({
    required this.profile,
    required this.currency,
    super.key,
  });

  final ProfileModel profile;
  final NumberFormat currency;

  @override
  State<ProfileTargetsCard> createState() => _ProfileTargetsCardState();
}

class _ProfileTargetsCardState extends State<ProfileTargetsCard> {
  final _repository = FinanceRepository();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    
    final progressToNextLevel = widget.profile.experiencePoints / 
        widget.profile.nextLevelThreshold;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.deepShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeader(
            theme: theme,
            level: widget.profile.level,
          ),
          const SizedBox(height: 16),
          _LevelProgressBar(progressToNextLevel: progressToNextLevel),
          const SizedBox(height: 10),
          _PointsText(
            theme: theme,
            currentPoints: widget.profile.experiencePoints,
            nextLevelThreshold: widget.profile.nextLevelThreshold,
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          _IndicatorsTitle(theme: theme),
          const SizedBox(height: 10),
          _IndicatorsSection(
            repository: _repository,
            tpsTarget: widget.profile.targetTps.toDouble(),
            rdrTarget: widget.profile.targetRdr.toDouble(),
            iliTarget: widget.profile.targetIli,
          ),
        ],
      ),
    );
  }
}

/// Header do card com icone e titulo.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.theme,
    required this.level,
  });

  final ThemeData theme;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.emoji_events,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progresso Geral',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Nivel $level',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barra de progresso para o proximo nivel.
class _LevelProgressBar extends StatelessWidget {
  const _LevelProgressBar({required this.progressToNextLevel});

  final double progressToNextLevel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: progressToNextLevel,
        minHeight: 10,
        backgroundColor: Colors.white24,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

/// Texto mostrando pontos atuais / pontos necessarios.
class _PointsText extends StatelessWidget {
  const _PointsText({
    required this.theme,
    required this.currentPoints,
    required this.nextLevelThreshold,
  });

  final ThemeData theme;
  final int currentPoints;
  final int nextLevelThreshold;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$currentPoints / $nextLevelThreshold pontos',
      style: theme.textTheme.bodySmall?.copyWith(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Titulo da secao de indicadores.
class _IndicatorsTitle extends StatelessWidget {
  const _IndicatorsTitle({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Indicadores Alvo',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Secao com os indicadores financeiros carregados via FutureBuilder.
class _IndicatorsSection extends StatelessWidget {
  const _IndicatorsSection({
    required this.repository,
    required this.tpsTarget,
    required this.rdrTarget,
    required this.iliTarget,
  });

  final FinanceRepository repository;
  final double tpsTarget;
  final double rdrTarget;
  final double iliTarget;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: repository.fetchDashboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingIndicator();
        }
        
        // Valores padrao se nao houver dados
        double tpsCurrent = 0;
        double rdrCurrent = 0;
        double iliCurrent = 0;
        
        if (snapshot.hasData) {
          final summary = snapshot.data!.summary;
          tpsCurrent = summary.tps;
          rdrCurrent = summary.rdr;
          iliCurrent = summary.ili;
        }
        
        return _IndicatorsList(
          tpsCurrent: tpsCurrent,
          rdrCurrent: rdrCurrent,
          iliCurrent: iliCurrent,
          tpsTarget: tpsTarget,
          rdrTarget: rdrTarget,
          iliTarget: iliTarget,
        );
      },
    );
  }
}

/// Indicador de carregamento.
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

/// Lista dos tres indicadores financeiros.
class _IndicatorsList extends StatelessWidget {
  const _IndicatorsList({
    required this.tpsCurrent,
    required this.rdrCurrent,
    required this.iliCurrent,
    this.tpsTarget = 20,
    this.rdrTarget = 35,
    this.iliTarget = 6,
  });

  final double tpsCurrent;
  final double rdrCurrent;
  final double iliCurrent;
  final double tpsTarget;
  final double rdrTarget;
  final double iliTarget;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TPS - Taxa de Poupanca
        FriendlyIndicatorCard(
          title: UxStrings.savings,
          value: tpsCurrent,
          target: tpsTarget,
          type: IndicatorType.percentage,
          subtitle: 'da sua renda',
          customIcon: Icons.savings_outlined,
        ),
        const SizedBox(height: 12),
        
        // RDR - Despesas Recorrentes
        FriendlyIndicatorCard(
          title: UxStrings.fixedExpensesMonthly,
          value: rdrCurrent,
          target: rdrTarget,
          type: IndicatorType.percentage,
          subtitle: 'comprometido da renda',
          customIcon: Icons.pie_chart_outline,
          lowerIsBetter: true, // Quanto MENOR, melhor!
        ),
        const SizedBox(height: 12),
        
        // ILI - Reserva de Emergencia
        FriendlyIndicatorCard(
          title: UxStrings.emergencyFundMonths,
          value: iliCurrent,
          target: iliTarget,
          type: IndicatorType.months,
          subtitle: 'para cobrir despesas',
          customIcon: Icons.health_and_safety_outlined,
        ),
      ],
    );
  }
}
