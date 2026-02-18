import 'dart:typed_data';
import 'package:flutter/material.dart';

class TryOnAnimationOverlay extends StatefulWidget {
  final Uint8List? userImageBytes;
  final Uint8List? clothingImageBytes;

  const TryOnAnimationOverlay({
    super.key,
    required this.userImageBytes,
    required this.clothingImageBytes,
  });

  @override
  State<TryOnAnimationOverlay> createState() => _TryOnAnimationOverlayState();
}

class _TryOnAnimationOverlayState extends State<TryOnAnimationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _moveController;
  late AnimationController _pulseController;

  late Animation<Offset> _userSlide;
  late Animation<Offset> _clothingSlide;
  late Animation<double> _fade;
  late Animation<double> _scalePulse;

  @override
  void initState() {
    super.initState();

    // 1. Movement Animation (Images fly to center)
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // User moves from Left (-1.5) to Center (0)
    _userSlide = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _moveController,
      curve: Curves.easeInOutCubic,
    ));

    // Clothing moves from Right (1.5) to Center (0)
    _clothingSlide = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _moveController,
      curve: Curves.easeInOutCubic,
    ));

    // Fade out as they merge
    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _moveController,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
      ),
    );

    // 2. Pulse Animation (Magic effect loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scalePulse = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start sequence
    _moveController.forward();
  }

  @override
  void dispose() {
    _moveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Backdrop blur or dark overlay
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center Magic Effect (Appears after merge)
          AnimatedBuilder(
            animation: _moveController,
            builder: (context, child) {
              final opacity = _moveController.value > 0.8 
                  ? (_moveController.value - 0.8) * 5 // 0.0 to 1.0
                  : 0.0;
              
              if (opacity <= 0) return const SizedBox.shrink();

              return Opacity(
                opacity: opacity.toDouble(),
                child: ScaleTransition(
                  scale: _scalePulse,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_fix_high, 
                        color: Color(0xFFC9A66B), // Gold
                        size: 80,
                        shadows: [
                          BoxShadow(color: Color(0xFFC9A66B), blurRadius: 20, spreadRadius: 5),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Создаем магию...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Flying Images
          AnimatedBuilder(
            animation: _moveController,
            builder: (context, child) {
              return Opacity(
                opacity: _fade.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // User Image
                    SlideTransition(
                      position: _userSlide,
                      child: _buildImageCard(widget.userImageBytes),
                    ),
                    
                    // Overlap
                    const SizedBox(width: 0), // They will overlap by sliding to 0 offset

                    // Clothing Image
                    SlideTransition(
                      position: _clothingSlide,
                      child: _buildImageCard(widget.clothingImageBytes),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(Uint8List? bytes) {
    if (bytes == null) return const SizedBox(width: 100, height: 150);

    return Container(
      width: 120, // Small thumbnail size
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
