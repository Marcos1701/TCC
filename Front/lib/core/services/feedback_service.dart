import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../constants/user_friendly_strings.dart';

/// Available feedback types
enum FeedbackType {
  success,
  error,
  warning,
  info,
  offline,
  serverError,
}

/// Feedback severity
enum FeedbackSeverity {
  low,
  medium,
  high,
  critical,
}

/// Configuration for a feedback type
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

/// Centralized service for displaying feedback to the user
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

  /// Displays a snackbar with feedback to the user
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

  /// Displays success feedback
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(context, message, type: FeedbackType.success, duration: duration);
  }

  /// Displays error feedback
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

  /// Displays warning feedback
  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(context, message, type: FeedbackType.warning, duration: duration);
  }

  /// Displays info feedback
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(context, message, type: FeedbackType.info, duration: duration);
  }

  /// Displays confirmation dialog
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

  /// Displays loading dialog
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

  /// Hides loading dialog
  static void hideLoadingDialog(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Displays an in-app notification (banner at the top)
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
              // Garante que opacity esteja sempre entre 0.0 e 1.0
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

    // Remove automaticamente após o duration
    Future.delayed(duration, removeEntry);
  }

  /// Exibe feedback de transação criada com sucesso
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

  /// Exibe feedback de missão completada
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

  /// Exibe feedback de meta alcançada
  static void showGoalAchieved(
    BuildContext context, {
    required String goalName,
    int? xpReward,
  }) {
    String message = '🎯 Meta alcançada!\n$goalName';
    
    if (xpReward != null && xpReward > 0) {
      message += '\n+$xpReward XP';
    }

    showBanner(
      context,
      message,
      type: FeedbackType.success,
      duration: const Duration(seconds: 5),
    );
  }

  /// Exibe feedback de level up
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

  /// Exibe feedback com ação personalizada
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

  /// Exibe feedback de erro com opção de retry
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

  /// Exibe notificação de progresso de missão
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

  /// Exibe aviso de missão próxima de expirar
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

  // ========== DIA 3: NOVOS MÉTODOS COM EMOJIS E CONTEXTO ==========

  /// Formata valor monetário para exibição
  static String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    ).format(value);
  }

  /// Exibe feedback específico de transação de receita
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

  /// Exibe feedback específico de transação de despesa
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

  /// Exibe feedback de progresso de meta
  static void showGoalProgress(
    BuildContext context, {
    required String goalName,
    required double progress,
    bool isCompleted = false,
  }) {
    if (isCompleted) {
      showBanner(
        context,
        '🎉 Meta "$goalName" alcançada!\nParabéns pela conquista!',
        type: FeedbackType.success,
        duration: const Duration(seconds: 5),
      );
    } else {
      final percentage = (progress * 100).toStringAsFixed(0);
      final emoji = progress >= 0.75 ? '🔥' : progress >= 0.5 ? '📊' : '💪';
      
      showBanner(
        context,
        '$emoji "$goalName": $percentage% completa',
        type: FeedbackType.info,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Exibe feedback de economia/poupança
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

  /// Exibe dica financeira contextual
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

  /// Exibe celebração de conquista
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

  /// Exibe feedback de sequência (streak)
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

  /// Exibe alerta de gasto alto
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

  /// Exibe feedback de economia bem-sucedida
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

  /// Exibe lembrete gentil
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

  /// Exibe feedback de desafio em andamento
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

  /// Exibe mensagem motivacional baseada no status financeiro
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

  /// Exibe feedback de amigo adicionado
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

  /// Exibe feedback de posição no ranking
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

  /// Exibe feedback de categoria de gasto
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
