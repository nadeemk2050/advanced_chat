import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Call [CelebrationOverlay.show] from anywhere to trigger a full-screen
/// confetti + rocket celebration with a custom headline.
class CelebrationOverlay {
  static void show(BuildContext context, {String title = 'MISSION COMPLETE!'}) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => _CelebrationDialog(title: title),
    );
  }
}

class _CelebrationDialog extends StatefulWidget {
  final String title;
  const _CelebrationDialog({required this.title});

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with TickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _rocketCtrl;
  late Animation<double> _rocketY;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _confetti = ConfettiController(duration: const Duration(seconds: 4))
      ..play();

    _rocketCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _rocketY = Tween<double>(begin: 0, end: -1).animate(
      CurvedAnimation(parent: _rocketCtrl, curve: Curves.easeInCubic),
    );
    _rocketCtrl.forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Auto-dismiss after 4.5 s
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _rocketCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // ---- Confetti cannons ----
        Align(
          alignment: Alignment.topLeft,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            blastDirection: pi / 4,
            numberOfParticles: 30,
            maxBlastForce: 35,
            minBlastForce: 15,
            gravity: 0.2,
            colors: const [
              Color(0xFFFFD700), Color(0xFFFF6B6B), Color(0xFF4ECDC4),
              Color(0xFF45B7D1), Color(0xFF96CEB4), Color(0xFFFF9F9F),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            blastDirection: 3 * pi / 4,
            numberOfParticles: 30,
            maxBlastForce: 35,
            minBlastForce: 15,
            gravity: 0.2,
            colors: const [
              Color(0xFFFFD700), Color(0xFF9B59B6), Color(0xFF3498DB),
              Color(0xFF1ABC9C), Color(0xFFE74C3C), Color(0xFFF39C12),
            ],
          ),
        ),

        // ---- Rocket ----
        AnimatedBuilder(
          animation: _rocketY,
          builder: (_, __) => Transform.translate(
            offset: Offset(
              0,
              _rocketY.value * MediaQuery.of(context).size.height * 0.6,
            ),
            child: const Text('🚀', style: TextStyle(fontSize: 80)),
          ),
        ),

        // ---- Badge card ----
        Center(
          child: ScaleTransition(
            scale: _pulse,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: ChatTheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: ChatTheme.primary.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: ChatTheme.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'VICTORY LOGGED TO THE VAULT',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
