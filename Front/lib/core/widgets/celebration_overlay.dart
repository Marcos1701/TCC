import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

/// Widget de overlay para celebrações com confetes e animações
class CelebrationOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onComplete;

  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();

  /// Exibe celebração de missão completada
  static void showMissionComplete({
    required BuildContext context,
    required String missionTitle,
    required int coinsEarned,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => CelebrationOverlay(
        title: '🎉 Missão Completada!',
        subtitle: '$missionTitle\n+$coinsEarned moedas',
        icon: Icons.emoji_events,
        color: Colors.amber,
        onComplete: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// Exibe celebração de subida de nível
  static void showLevelUp({
    required BuildContext context,
    required int newLevel,
    required int coinsEarned,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => CelebrationOverlay(
        title: '⭐ Subiu de Nível!',
        subtitle: 'Nível $newLevel\n+$coinsEarned moedas de bônus',
        icon: Icons.stars,
        color: Colors.purple,
        onComplete: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Controlador de confetes
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Controlador de escala (bounce)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Controlador de rotação
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.easeInOut,
      ),
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

    // Iniciar animações
    _confettiController.play();
    _scaleController.forward();
    _rotationController.repeat(reverse: true);
    
    // Auto-fechar após 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      _fadeController.forward().then((_) {
        if (mounted) {
          widget.onComplete();
        }
      });
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Confetes caindo
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // Para baixo
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.3,
            colors: const [
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.yellow,
              Colors.purple,
              Colors.orange,
              Colors.pink,
            ],
          ),
        ),

        // Confetes do lado esquerdo
        Align(
          alignment: Alignment.centerLeft,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: 0, // Para a direita
            maxBlastForce: 10,
            minBlastForce: 5,
            emissionFrequency: 0.1,
            numberOfParticles: 20,
            gravity: 0.1,
            colors: const [
              Colors.amber,
              Colors.deepOrange,
              Colors.teal,
            ],
          ),
        ),

        // Confetes do lado direito
        Align(
          alignment: Alignment.centerRight,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi, // Para a esquerda
            maxBlastForce: 10,
            minBlastForce: 5,
            emissionFrequency: 0.1,
            numberOfParticles: 20,
            gravity: 0.1,
            colors: const [
              Colors.amber,
              Colors.deepOrange,
              Colors.teal,
            ],
          ),
        ),

        // Card de celebração
        Center(
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnimation),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: RotationTransition(
                turns: _rotationAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.all(40),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ícone animado
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            size: 60,
                            color: widget.color,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Título
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: widget.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        
                        // Subtítulo
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        
                        // Botão de continuar
                        ElevatedButton(
                          onPressed: () {
                            _fadeController.forward().then((_) {
                              widget.onComplete();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Continuar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
}
