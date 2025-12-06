import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../constants/user_friendly_strings.dart';

enum FeedbackType {
  success,
  error,
  warning,
  info,
  offline,
  serverError,
}

enum FeedbackSeverity {
  low,
  medium,
  high,
  critical,
}

class FeedbackConfig {
  final Color backgroundColor;
  final IconData icon;
  final Duration duration;

  const FeedbackConfig({
    required this.backgroundColor,
    required this.icon,
    this.duration = const Duration(seconds: 4),
  });
}

class FeedbackService {
  static const Map<FeedbackType, FeedbackConfig> _configs = {
    FeedbackType.success: FeedbackConfig(
      backgroundColor: AppColors.support,
      icon: Icons.check_circle,
      duration: Duration(seconds: 3),
    ),
    FeedbackType.error: FeedbackConfig(
      backgroundColor: AppColors.alert,
      icon: Icons.error,
      duration: Duration(seconds: 5),
    ),
    FeedbackType.warning: FeedbackConfig(
      backgroundColor: AppColors.highlight,
      icon: Icons.warning_amber,
      duration: Duration(seconds: 4),
    ),
    FeedbackType.info: FeedbackConfig(
      backgroundColor: Color(0xFF3B82F6),
      icon: Icons.info,
      duration: Duration(seconds: 4),
    ),
    FeedbackType.offline: FeedbackConfig(
      backgroundColor: Color(0xFF6B7280),
      icon: Icons.cloud_off,
      duration: Duration(seconds: 4),
    ),
    FeedbackType.serverError: FeedbackConfig(
      backgroundColor: Color(0xFFFF6B6B),
      icon: Icons.dns,
      duration: Duration(seconds: 5),
    ),
  };

  static void show(
    BuildContext context,
    String message, {
    required FeedbackType type,
    Duration? duration,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    final config = _configs[type]!;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(config.icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration ?? config.duration,
        action: action,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(context, message, type: FeedbackType.success, duration: duration);
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      type: FeedbackType.error,
      duration: duration,
      action: action,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(context, message, type: FeedbackType.warning, duration: duration);
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(context, message, type: FeedbackType.info, duration: duration);
  }

  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF10121D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              isDangerous ? Icons.warning_amber : Icons.help_outline,
              color: isDangerous ? AppColors.alert : AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: isDangerous ? AppColors.alert : AppColors.primary,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  static void showLoadingDialog(
    BuildContext context, {
    String message = 'Processando...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: const Color(0xFF10121D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  static void showBanner(
    BuildContext context,
    String message, {
    required FeedbackType type,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    if (!context.mounted) return;

    final config = _configs[type]!;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    bool isRemoving = false;

    void removeEntry() {
      if (isRemoving || !entry.mounted) return;
      isRemoving = true;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              final clampedValue = value.clamp(0.0, 1.0);
              final offset = (-50.0 * (1.0 - clampedValue)).clamp(-50.0, 0.0);
              
              return Transform.translate(
                offset: Offset(0, offset),
                child: Opacity(
                  opacity: clampedValue,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                removeEntry();
                onTap?.call();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: config.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(config.icon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(duration, removeEntry);
  }

  static void showTransactionCreated(
    BuildContext context, {
    required double amount,
    required String type,
    int? xpEarned,
    String? missionProgress,
  }) {
    final emoji = type == 'INCOME' ? '💰' : type == 'EXPENSE' ? '💸' : '💳';
    String message = '$emoji Transação registrada!';
    
    if (xpEarned != null && xpEarned > 0) {
      message += ' +$xpEarned XP 🎉';
    }
    
    if (missionProgress != null) {
      message += '\n$missionProgress';
    }

    show(
      context,
      message,
      type: FeedbackType.success,
      duration: const Duration(seconds: 4),
    );
  }

  static void showMissionCompleted(
    BuildContext context, {
    required String missionName,
    required int xpReward,
    int? coinsReward,
  }) {
    String message = '🎊 Missão completada!\n$missionName';
    message += '\n+$xpReward XP';
    
    if (coinsReward != null && coinsReward > 0) {
      message += ' • +$coinsReward moedas';
    }

    showBanner(
      context,
      message,
      type: FeedbackType.success,
      duration: const Duration(seconds: 5),
    );
  }


  static void showLevelUp(
    BuildContext context, {
    required int newLevel,
    int? coinsEarned,
  }) {
    String message = '⭐ Subiu de nível!\nAgora você é nível $newLevel';
    
    if (coinsEarned != null && coinsEarned > 0) {
      message += '\n+$coinsEarned moedas';
    }

    showBanner(
      context,
      message,
      type: FeedbackType.success,
      duration: const Duration(seconds: 6),
    );
  }

  static void showSuccessWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    show(
      context,
      message,
      type: FeedbackType.success,
      action: SnackBarAction(
        label: actionLabel,
        textColor: Colors.white,
        onPressed: onAction,
      ),
    );
  }

  static void showErrorWithRetry(
    BuildContext context,
    String message, {
    required VoidCallback onRetry,
  }) {
    show(
      context,
      message,
      type: FeedbackType.error,
      action: SnackBarAction(
        label: 'Tentar Novamente',
        textColor: Colors.white,
        onPressed: onRetry,
      ),
    );
  }

  static void showMissionProgress(
    BuildContext context, {
    required String missionName,
    required double progress,
  }) {
    final progressText = '${progress.toStringAsFixed(0)}%';
    showBanner(
      context,
      '📈 $missionName: $progressText completo',
      type: FeedbackType.info,
      duration: const Duration(seconds: 3),
    );
  }

  static void showMissionExpiring(
    BuildContext context, {
    required String missionName,
    required int daysRemaining,
  }) {
    showBanner(
      context,
      '⏰ $missionName expira em $daysRemaining ${daysRemaining == 1 ? 'dia' : 'dias'}!',
      type: FeedbackType.warning,
      duration: const Duration(seconds: 5),
    );
  }


  static String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    ).format(value);
  }

  static void showIncomeAdded(
    BuildContext context, {
    required double amount,
    int? pointsEarned,
  }) {
    String message = '💰 Você recebeu ${_formatCurrency(amount)}';
    
    if (pointsEarned != null && pointsEarned > 0) {
      message += '\n⭐ +$pointsEarned ${UxStrings.points}!';
    }

    show(
      context,
      message,
      type: FeedbackType.success,
      duration: const Duration(seconds: 3),
    );
  }

  static void showExpenseAdded(
    BuildContext context, {
    required double amount,
    String? category,
    int? pointsEarned,
  }) {
    String message = '💸 Você gastou ${_formatCurrency(amount)}';
    
    if (category != null) {
      message += ' em $category';
    }
    
    if (pointsEarned != null && pointsEarned > 0) {
      message += '\n⭐ +$pointsEarned ${UxStrings.points} por registrar!';
    }

    show(
      context,
      message,
      type: FeedbackType.info,
      duration: const Duration(seconds: 3),
    );
  }


  static void showSavingsAchievement(
    BuildContext context, {
    required double amount,
    required double target,
  }) {
    final progress = (amount / target * 100).toStringAsFixed(0);
    final emoji = amount >= target ? '🎯' : amount >= (target * 0.7) ? '💪' : '🌱';
    
    showBanner(
      context,
      '$emoji Você já guardou ${_formatCurrency(amount)} ($progress% da meta)!',
      type: amount >= target ? FeedbackType.success : FeedbackType.info,
      duration: const Duration(seconds: 4),
    );
  }

  static void showFinancialTip(
    BuildContext context, {
    required String tip,
  }) {
    showBanner(
      context,
      '💡 Dica: $tip',
      type: FeedbackType.info,
      duration: const Duration(seconds: 6),
    );
  }

  static void showAchievementUnlocked(
    BuildContext context, {
    required String achievementName,
    String? description,
    int? pointsEarned,
  }) {
    String message = '🏆 Conquista desbloqueada!\n$achievementName';
    
    if (description != null) {
      message += '\n$description';
    }
    
    if (pointsEarned != null && pointsEarned > 0) {
      message += '\n⭐ +$pointsEarned ${UxStrings.points}';
    }

    showBanner(
      context,
      message,
      type: FeedbackType.success,
      duration: const Duration(seconds: 6),
    );
  }

  static void showStreak(
    BuildContext context, {
    required int days,
    String action = 'registrando transações',
  }) {
    final emoji = days >= 30 ? '🔥' : days >= 7 ? '⚡' : '✨';
    
    showBanner(
      context,
      '$emoji $days ${days == 1 ? 'dia' : 'dias'} consecutivos $action!',
      type: FeedbackType.success,
      duration: const Duration(seconds: 4),
    );
  }

  static void showHighExpenseAlert(
    BuildContext context, {
    required double amount,
    required String category,
    double? monthlyAverage,
  }) {
    String message = '⚠️ Gasto alto detectado!\n${_formatCurrency(amount)} em $category';
    
    if (monthlyAverage != null && amount > monthlyAverage * 1.5) {
      final percentageOver = ((amount / monthlyAverage - 1) * 100).toStringAsFixed(0);
      message += '\n$percentageOver% acima da média mensal';
    }

    showBanner(
      context,
      message,
      type: FeedbackType.warning,
      duration: const Duration(seconds: 5),
    );
  }

  static void showSavingSuccess(
    BuildContext context, {
    required double amountSaved,
    required String comparedTo,
  }) {
    showBanner(
      context,
      '🎊 Você economizou ${_formatCurrency(amountSaved)} comparado $comparedTo!',
      type: FeedbackType.success,
      duration: const Duration(seconds: 4),
    );
  }

  static void showGentleReminder(
    BuildContext context, {
    required String message,
    VoidCallback? onTap,
  }) {
    showBanner(
      context,
      '🔔 $message',
      type: FeedbackType.info,
      duration: const Duration(seconds: 5),
      onTap: onTap,
    );
  }

  static void showChallengeProgress(
    BuildContext context, {
    required String challengeName,
    required int current,
    required int target,
  }) {
    final percentage = ((current / target) * 100).toStringAsFixed(0);
    final emoji = current >= target ? '🎯' : current >= (target * 0.8) ? '🔥' : '💪';
    
    showBanner(
      context,
      '$emoji $challengeName: $current/$target ($percentage%)',
      type: current >= target ? FeedbackType.success : FeedbackType.info,
      duration: const Duration(seconds: 3),
    );
  }

  static void showMotivationalMessage(
    BuildContext context, {
    required String message,
    bool isPositive = true,
  }) {
    final emoji = isPositive ? '💪' : '🌱';
    
    showBanner(
      context,
      '$emoji $message',
      type: isPositive ? FeedbackType.success : FeedbackType.info,
      duration: const Duration(seconds: 4),
    );
  }

  static void showFriendAdded(
    BuildContext context, {
    required String friendName,
    int? pointsEarned,
  }) {
    String message = '👋 Você adicionou $friendName como amigo!';
    
    if (pointsEarned != null && pointsEarned > 0) {
      message += '\n⭐ +$pointsEarned ${UxStrings.points}';
    }

    show(
      context,
      message,
      type: FeedbackType.success,
      duration: const Duration(seconds: 3),
    );
  }

  static void showRankingUpdate(
    BuildContext context, {
    required int newRank,
    required int oldRank,
    int? totalFriends,
  }) {
    final isImprovement = newRank < oldRank;
    final emoji = isImprovement ? '📈' : '📊';
    
    String message = '$emoji Você está em $newRankº lugar';
    
    if (totalFriends != null) {
      message += ' entre $totalFriends amigos';
    }
    
    if (isImprovement && oldRank > 0) {
      final positionsUp = oldRank - newRank;
      message += '\n🎉 Subiu $positionsUp ${positionsUp == 1 ? 'posição' : 'posições'}!';
    }

    show(
      context,
      message,
      type: isImprovement ? FeedbackType.success : FeedbackType.info,
      duration: const Duration(seconds: 4),
    );
  }

  static void showCategoryInsight(
    BuildContext context, {
    required String category,
    required double amount,
    required double percentage,
  }) {
    final emoji = percentage >= 40 ? '⚠️' : percentage >= 25 ? '📊' : '✅';
    
    showBanner(
      context,
      '$emoji $category: ${_formatCurrency(amount)} (${percentage.toStringAsFixed(0)}% dos gastos)',
      type: percentage >= 40 ? FeedbackType.warning : FeedbackType.info,
      duration: const Duration(seconds: 4),
    );
  }
}
