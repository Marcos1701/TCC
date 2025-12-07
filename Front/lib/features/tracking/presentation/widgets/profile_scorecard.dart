import 'package:flutter/material.dart';

import '../../../../core/models/analytics.dart';
import '../../../../core/theme/app_colors.dart';

/// Displays the user's gamification profile (Level, Tier, XP Progress).
class ProfileScorecard extends StatelessWidget {
  const ProfileScorecard({super.key, required this.tier});

  final TierInfo tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(60),
            AppColors.primary.withAlpha(30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withAlpha(100),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTierBadge(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tierDisplayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nível ${tier.level}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.highlight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildXpProgress(theme),
          const SizedBox(height: 12),
          Text(
            tier.tierDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge() {
    IconData icon;
    Color color;

    switch (tier.tier) {
      case 'BEGINNER':
        icon = Icons.emoji_events_outlined;
        color = Colors.green;
        break;
      case 'INTERMEDIATE':
        icon = Icons.star_half_rounded;
        color = AppColors.highlight;
        break;
      case 'ADVANCED':
        icon = Icons.star_rounded;
        color = Colors.deepOrange;
        break;
      default:
        icon = Icons.emoji_events_outlined;
        color = Colors.grey;
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildXpProgress(ThemeData theme) {
    final progress = tier.xpProgressInLevel.clamp(0.0, 100.0) / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'XP: ${tier.xp}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            Text(
              'Próximo: ${tier.nextLevelXp}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(AppColors.highlight),
          ),
        ),
      ],
    );
  }

  String get _tierDisplayName {
    switch (tier.tier) {
      case 'BEGINNER':
        return 'Iniciante';
      case 'INTERMEDIATE':
        return 'Intermediário';
      case 'ADVANCED':
        return 'Avançado';
      default:
        return tier.tier;
    }
  }
}
