import 'package:flutter/material.dart';
import '../animations/bouncing_button.dart';

/// Premium action button - VOGUE.AI style
class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isOutlined;

  const ActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    // Define colors based on type
    final backgroundColor = isOutlined 
        ? Colors.transparent 
        : (isPrimary ? primaryColor : theme.colorScheme.surface);
    
    final textColor = isOutlined 
        ? primaryColor 
        : (isPrimary ? Colors.white : primaryColor);

    return BouncingButton(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30),
          border: isOutlined ? Border.all(color: primaryColor, width: 1) : null,
          boxShadow: isOutlined || !isPrimary ? null : [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
