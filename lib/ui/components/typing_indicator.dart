import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final Color? color;

  const TypingIndicator({super.key, this.color});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final offset = (index * 0.2); // Stagger animation
              final value = (_animation.value + offset) % 1.0;
              final sinValue = (value * 3.14159).abs(); // 0 to 1 to 0 (approx)
              
              // Use sin for smooth bouncing
              final scale = 0.6 + (0.4 * (1 - (value - 0.5).abs() * 2)); 

              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: (widget.color ?? Theme.of(context).primaryColor).withOpacity(
                    (0.4 + 0.6 * scale).clamp(0.0, 1.0)
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
