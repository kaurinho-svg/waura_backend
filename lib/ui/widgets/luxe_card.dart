import 'package:flutter/material.dart';

class LuxeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const LuxeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: gold.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}