import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import '../theme/app_colors.dart';
import '../constants/user_friendly_strings.dart';

/// Widget de overlay para celebrações com confetes e animações
class CelebrationOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onComplete;
  final bool showConfetti;

  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onComplete,
    this.showConfetti = true,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();

  /// Exibe celebração de desafio completado
  static void showMissionComplete({
    required BuildContext context,
    required String missionTitle,
    required int coinsEarned,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => CelebrationOverlay(
        title: '${UxStrings.challenge} Completado!',
        subtitle: '$missionTitle\n+$coinsEarned ${UxStrings.point.toLowerCase()}',
        icon: Icons.emoji_events,
        color: AppColors.support,
        onComplete: () => Navigator.of(context).pop(),
        showConfetti: true,
      ),
    );
  }

  /// Exibe celebração de subida de nível (moderna e minimalista)
  static void showLevelUp({
    required BuildContext context,
    required int newLevel,
    required int coinsEarned,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => CelebrationOverlay(
        title: 'Nível $newLevel',
        subtitle: 'Parabéns pelo progresso!\n+$coinsEarned ${UxStrings.point.toLowerCase()} de bônus',
        icon: Icons.workspace_premium,
        color: AppColors.primary,
        onComplete: () => Navigator.of(context).pop(),
        showConfetti: false, // Sem confetes para level up
      ),
    );
  }
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late ConfettiController? _confettiController;
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _glowController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Controlador de confetes (apenas se necessário)
    if (widget.showConfetti) {
      _confettiController = ConfettiController(
        duration: const Duration(seconds: 2),
      );
      _confettiController!.play();
    } else {
      _confettiController = null;
    }

    // Controlador de escala (suave)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    // Controlador de fade
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Controlador de brilho pulsante (apenas para level up)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Iniciar animações
    _scaleController.forward();
    if (!widget.showConfetti) {
      // Apenas para level up - efeito pulsante sutil
      _glowController.repeat(reverse: true);
    }
    
    // Auto-fechar após 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _fadeController.forward().then((_) {
          if (mounted) {
            widget.onComplete();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _confettiController?.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Confetes caindo (apenas para desafios)
        if (widget.showConfetti && _confettiController != null) ...[
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController!,
              blastDirection: pi / 2, // Para baixo
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.3,
              colors: [
                AppColors.primary,
                AppColors.support,
                AppColors.highlight,
                widget.color,
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ConfettiWidget(
              confettiController: _confettiController!,
              blastDirection: 0, // Para a direita
              maxBlastForce: 8,
              minBlastForce: 4,
              emissionFrequency: 0.1,
              numberOfParticles: 15,
              gravity: 0.1,
              colors: const [
                AppColors.primary,
                AppColors.support,
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ConfettiWidget(
              confettiController: _confettiController!,
              blastDirection: pi, // Para a esquerda
              maxBlastForce: 8,
              minBlastForce: 4,
              emissionFrequency: 0.1,
              numberOfParticles: 15,
              gravity: 0.1,
              colors: const [
                AppColors.primary,
                AppColors.support,
              ],
            ),
          ),
        ],

        // Card de celebração moderno
        Center(
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnimation),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF10121D),
                        Color(0xFF1A1D2E),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.color.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),
                      
                      // Ícone com efeito de brilho
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  widget.color.withOpacity(
                                    widget.showConfetti ? 0.2 : _glowAnimation.value,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: widget.color.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  widget.icon,
                                  size: 50,
                                  color: widget.color,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      
                      // Título
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: widget.color,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Subtítulo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Botão de continuar moderno
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _fadeController.forward().then((_) {
                                if (mounted) {
                                  widget.onComplete();
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Continuar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
