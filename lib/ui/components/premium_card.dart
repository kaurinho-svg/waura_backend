import 'package:flutter/material.dart';
import '../animations/bouncing_button.dart';

/// Premium white card with soft shadow - VOGUE.AI style
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin; 
  final VoidCallback? onTap;
  final double? borderRadius;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: theme.colorScheme.secondary.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return BouncingButton(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}
