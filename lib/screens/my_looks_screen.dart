import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/looks_provider.dart';
import '../ui/layouts/luxe_scaffold.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class MyLooksScreen extends StatelessWidget {
  static const route = '/my-looks';

  const MyLooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return LuxeScaffold(
      title: context.tr('my_looks_title'),
      child: Consumer<LooksProvider>(
        builder: (context, provider, _) {
          final looks = provider.looks;

          return Column(
            children: [
              // Верхняя панель действий (вместо AppBar actions)
              Row(
                children: [
                  const Spacer(),
                  _LuxeIconButton(
                    icon: Icons.delete_sweep_outlined,
                    tooltip: context.tr('my_looks_clear_all'),
                    onTap: () async {
                      if (provider.looks.isEmpty) return;

                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(context.tr('my_looks_delete_confirm_title')),
                          content: Text(
                            context.tr('my_looks_delete_confirm_content'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(context.tr('my_looks_cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(context.tr('my_looks_delete')),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        await provider.clearAll();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Expanded(
                child: looks.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: gold.withOpacity(0.22)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.collections_bookmark_outlined,
                                size: 34,
                                color:
                                    theme.colorScheme.primary.withOpacity(0.9),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.tr('my_looks_empty_title'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.tr('my_looks_empty_subtitle'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(top: 6),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.sizeOf(context).width > 900 ? 4 : 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 3 / 4,
                        ),
                        itemCount: looks.length,
                        itemBuilder: (context, index) {
                          final look = looks[index];
                          return _LookCard(
                            lookId: look.id,
                            imageUrl: look.resultImageUrl,
                            prompt: look.prompt,
                            createdAt: look.createdAt,
                            onDelete: () => provider.deleteLook(look.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}

class _LookCard extends StatelessWidget {
  final String lookId;
  final String imageUrl;
  final String prompt;
  final DateTime createdAt;
  final VoidCallback onDelete;

  const _LookCard({
    required this.lookId,
    required this.imageUrl,
    required this.prompt,
    required this.createdAt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;
    final paper2 = theme.cardTheme.color ?? theme.colorScheme.surface;

    String formatDateTime(DateTime dt) {
      final d = dt.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(d.day)}.${two(d.month)}.${d.year} '
          '${two(d.hour)}:${two(d.minute)}';
    }

    return Container(
      decoration: BoxDecoration(
        color: paper2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    backgroundColor: theme.scaffoldBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: gold.withOpacity(0.22)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: InteractiveViewer(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Hero(
                tag: lookId,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(context.tr('my_looks_image_error')),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt.isEmpty ? context.tr('my_looks_no_prompt') : prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatDateTime(createdAt),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ),
                    _LuxeMiniDeleteButton(onTap: onDelete),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LuxeIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _LuxeIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gold.withOpacity(0.25)),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}

class _LuxeMiniDeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LuxeMiniDeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withOpacity(0.22)),
        ),
        child: Icon(
          Icons.delete_outline,
          size: 18,
          color: theme.colorScheme.primary.withOpacity(0.9),
        ),
      ),
    );
  }
}