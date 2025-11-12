import 'package:flutter/material.dart';
import '../../data/models/achievement.dart';

/// Card de conquista mostrando progresso e informações
class AchievementCard extends StatelessWidget {
  final UserAchievement userAchievement;
  final VoidCallback? onTap;
  final bool showProgress;

  const AchievementCard({
    super.key,
    required this.userAchievement,
    this.onTap,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final achievement = userAchievement.achievement;
    final isUnlocked = userAchievement.isUnlocked;
    final isClose = userAchievement.isCloseToUnlock;

    return Card(
      elevation: isUnlocked ? 4 : 2,
      color: isUnlocked
          ? Theme.of(context).colorScheme.primaryContainer
          : isClose
              ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5)
              : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Ícone, Título e Pontos
              Row(
                children: [
                  // Ícone
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        achievement.icon,
                        style: TextStyle(
                          fontSize: 32,
                          color: isUnlocked ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Título e Categoria
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? null : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Badge de categoria
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(achievement.category).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                achievement.categoryName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getCategoryColor(achievement.category),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // Badge de tier
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getTierColor(achievement.tier).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                achievement.tierName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getTierColor(achievement.tier),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Badge de Pontos
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '+${achievement.xpReward}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Descrição
              Text(
                achievement.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isUnlocked ? null : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Critério
              Row(
                children: [
                  Icon(
                    _getCriteriaIcon(achievement.criteria.type),
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      achievement.criteria.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // Progresso (se não desbloqueada e showProgress=true)
              if (!isUnlocked && showProgress) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progresso',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          userAchievement.progressDescription,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isClose
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: userAchievement.progressPercentage / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isClose
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              // Data de desbloqueio (se desbloqueada)
              if (isUnlocked && userAchievement.unlockedAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Desbloqueada em ${_formatDate(userAchievement.unlockedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'FINANCIAL':
        return Colors.green;
      case 'SOCIAL':
        return Colors.blue;
      case 'MISSION':
        return Colors.purple;
      case 'STREAK':
        return Colors.orange;
      case 'GENERAL':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'BEGINNER':
        return Colors.lightGreen;
      case 'INTERMEDIATE':
        return Colors.deepOrange;
      case 'ADVANCED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCriteriaIcon(String type) {
    switch (type) {
      case 'count':
        return Icons.format_list_numbered;
      case 'value':
        return Icons.show_chart;
      case 'streak':
        return Icons.local_fire_department;
      default:
        return Icons.flag;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
