import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Быстрые вопросы для консультанта (High Visibility)
class QuickQuestionChips extends StatelessWidget {
  final Function(String) onQuestionSelected;

  const QuickQuestionChips({
    super.key,
    required this.onQuestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<String> questions = [
      context.tr('consultant_chip_today'),
      context.tr('consultant_chip_date'),
      context.tr('consultant_chip_work'),
      context.tr('consultant_chip_trends'),
      context.tr('consultant_chip_audit'),
      context.tr('consultant_chip_color'),
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => onQuestionSelected(question),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.black.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  )
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                question,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
