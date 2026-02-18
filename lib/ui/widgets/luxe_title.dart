import 'package:flutter/material.dart';

class LuxeTitle extends StatelessWidget {
  final String text;
  const LuxeTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return Column(
      children: [
        Text(text, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Divider(color: gold.withOpacity(0.35), thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Expanded(child: Divider(color: gold.withOpacity(0.35), thickness: 1)),
          ],
        ),
      ],
    );
  }
}