import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Tipos de feedback disponíveis
enum FeedbackType {
  success,
  error,
  warning,
  info,
  offline,
  serverError,
}

/// Severidade do feedback
enum FeedbackSeverity {
  low,
  medium,
  high,
  critical,
}

/// Configuração de um tipo de feedback
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

/// Serviço centralizado para exibição de feedbacks ao usuário
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

  /// Exibe um snackbar com feedback ao usuário
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

  /// Exibe feedback de sucesso
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(context, message, type: FeedbackType.success, duration: duration);
  }

  /// Exibe feedback de erro
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

  /// Exibe feedback de aviso
  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(context, message, type: FeedbackType.warning, duration: duration);
  }

  /// Exibe feedback informativo
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(context, message, type: FeedbackType.info, duration: duration);
  }

  /// Exibe diálogo de confirmação
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

  /// Exibe diálogo de loading
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

  /// Fecha o diálogo de loading
  static void hideLoadingDialog(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Exibe uma notificação in-app (banner no topo)
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
}
