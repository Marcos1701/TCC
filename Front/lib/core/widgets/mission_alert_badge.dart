import 'package:flutter/material.dart';
import '../services/mission_notification_service.dart';
import '../theme/app_colors.dart';

/// Widget que exibe um badge com alertas de missões urgentes
class MissionAlertBadge extends StatelessWidget {
  final MissionSummary summary;
  final VoidCallback onTap;

  const MissionAlertBadge({
    super.key,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!summary.hasUrgentMissions && !summary.hasExpiredMissions) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: summary.hasExpiredMissions
              ? AppColors.alert.withOpacity(0.15)
              : AppColors.highlight.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: summary.hasExpiredMissions
                ? AppColors.alert
                : AppColors.highlight,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: summary.hasExpiredMissions
                    ? AppColors.alert
                    : AppColors.highlight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                summary.hasExpiredMissions
                    ? Icons.error_outline
                    : Icons.warning_amber_rounded,
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
                    summary.hasExpiredMissions
                        ? 'Missões Expiradas'
                        : 'Missões Expirando Em Breve',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.hasExpiredMissions
                        ? '${summary.expiredCount} ${summary.expiredCount == 1 ? "missão expirou" : "missões expiraram"}'
                        : '${summary.expiringSoon} ${summary.expiringSoon == 1 ? "missão expira" : "missões expiram"} em menos de 24h',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget que exibe um resumo compacto das missões
class MissionStatusCard extends StatelessWidget {
  final MissionSummary summary;
  final VoidCallback onTap;

  const MissionStatusCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.2),
              AppColors.primary.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.assignment_turned_in,
              label: 'Ativas',
              value: '${summary.activeCount}',
              color: AppColors.primary,
            ),
            if (summary.hasUrgentMissions)
              _StatItem(
                icon: Icons.access_time,
                label: 'Urgentes',
                value: '${summary.expiringSoon}',
                color: AppColors.highlight,
              ),
            if (summary.hasCompletedToday)
              _StatItem(
                icon: Icons.check_circle,
                label: 'Hoje',
                value: '${summary.completedToday}',
                color: AppColors.support,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
