import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../data/models/achievement.dart';

/// Serviço para mostrar notificações de conquistas desbloqueadas
/// 
/// Uso:
/// ```dart
/// AchievementNotification.show(
///   context,
///   achievement: achievement,
///   xpAwarded: 50,
/// );
/// ```
class AchievementNotification {
  static OverlayEntry? _currentOverlay;
  static ConfettiController? _confettiController;

  /// Mostra notificação de conquista desbloqueada
  /// 
  /// Parâmetros:
  /// - [context]: BuildContext atual
  /// - [achievement]: Conquista desbloqueada
  /// - [xpAwarded]: XP concedido
  /// - [duration]: Duração da notificação (padrão: 5 segundos)
  /// - [showConfetti]: Se deve mostrar confetti (padrão: true)
  static void show(
    BuildContext context, {
    required Achievement achievement,
    required int xpAwarded,
    Duration duration = const Duration(seconds: 5),
    bool showConfetti = true,
  }) {
    // Remover notificação anterior se existir
    dismiss();

    // Criar controller de confetti
    if (showConfetti) {
      _confettiController = ConfettiController(
        duration: const Duration(seconds: 3),
      );
    }

    // Criar overlay entry
    _currentOverlay = OverlayEntry(
      builder: (context) => _AchievementNotificationWidget(
        achievement: achievement,
        xpAwarded: xpAwarded,
        onDismiss: dismiss,
        confettiController: _confettiController,
      ),
    );

    // Adicionar ao overlay
    Overlay.of(context).insert(_currentOverlay!);

    // Iniciar confetti
    if (showConfetti && _confettiController != null) {
      _confettiController!.play();
    }

    // Auto-dismiss após duração
    Future.delayed(duration, dismiss);
  }

  /// Remove a notificação atual
  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _confettiController?.dispose();
    _confettiController = null;
  }
}

/// Widget interno da notificação
class _AchievementNotificationWidget extends StatefulWidget {
  final Achievement achievement;
  final int xpAwarded;
  final VoidCallback onDismiss;
  final ConfettiController? confettiController;

  const _AchievementNotificationWidget({
    required this.achievement,
    required this.xpAwarded,
    required this.onDismiss,
    this.confettiController,
  });

  @override
  State<_AchievementNotificationWidget> createState() =>
      _AchievementNotificationWidgetState();
}

class _AchievementNotificationWidgetState
    extends State<_AchievementNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Confetti
        if (widget.confettiController != null)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: widget.confettiController!,
              blastDirection: 3.14 / 2, // Vertical para baixo
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow,
              ],
            ),
          ),

        // Notificação
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: _dismiss,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header: Título
                          Row(
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Conquista Desbloqueada!',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: _dismiss,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Corpo: Conquista
                          Row(
                            children: [
                              // Ícone grande
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    widget.achievement.icon,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Informações
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Título da conquista
                                    Text(
                                      widget.achievement.title,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    
                                    // Descrição
                                    Text(
                                      widget.achievement.description,
                                      style: Theme.of(context).textTheme.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Badges
                                    Row(
                                      children: [
                                        // Categoria
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(widget.achievement.category)
                                                .withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            widget.achievement.categoryName,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _getCategoryColor(widget.achievement.category),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        
                                        // XP
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.amber,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.stars,
                                                size: 12,
                                                color: Colors.amber,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+${widget.xpAwarded} XP',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
}
