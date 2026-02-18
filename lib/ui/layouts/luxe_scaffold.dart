// lib/ui/layouts/luxe_scaffold.dart
import 'package:flutter/material.dart';

class LuxeScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  /// Если false — кнопка назад скрыта (например, на HomeScreen)
  final bool showBack;

  /// Если true — контент будет скроллиться (лечит OVERFLOW на телефоне/клавиатуре)
  /// Если у экрана внутри есть Expanded/Row во всю высоту (TryOn и т.п.) — ставь false.
  final bool scroll;

  final List<Widget>? actions; // [NEW] Support for top-right actions

  const LuxeScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showBack = true,
    this.scroll = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    // ... (theme vars) ...
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 420;

    // ... (titleStyle) ...
    final titleStyle =
        isNarrow ? theme.textTheme.titleLarge : theme.textTheme.headlineMedium;

    Widget header() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: back + title
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showBack && Navigator.of(context).canPop())
                  _BackButtonLuxe(gold: gold)
                else
                  const SizedBox(width: 44), 

                Expanded(
                  child: Center(
                    child: Text(
                      title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Right side: Actions or placeholder
                if (actions != null && actions!.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: actions!)
                else
                  const SizedBox(width: 44),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Divider(color: gold.withOpacity(0.35), thickness: 1),
                ),
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
                Expanded(
                  child: Divider(color: gold.withOpacity(0.35), thickness: 1),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        );

    // общий контейнер, чтобы не дублировать
    Widget shell({required Widget body}) {
      final mq = MediaQuery.of(context);

      // ✅ добавляем чуть места снизу под системную навигацию (часто это те самые 2–4px)
      final bottomSafe = mq.viewPadding.bottom;
      final extraBottom = bottomSafe > 0 ? 0.0 : 6.0; // на устройствах без inset

      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                18 + extraBottom,
              ),
              child: body,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true, // важно для клавиатуры
      body: scroll
          // ✅ Скролл-режим: убирает BOTTOM OVERFLOW при клавиатуре и на маленьких экранах
          ? shell(
              body: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header(),
                    child,
                  ],
                ),
              ),
            )
          // ✅ Режим без скролла: для экранов с Expanded/Row на всю высоту
          : shell(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header(),
                  Expanded(child: child),
                ],
              ),
            ),
    );
  }
}

class _BackButtonLuxe extends StatelessWidget {
  final Color gold;
  const _BackButtonLuxe({required this.gold});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold.withOpacity(0.25)),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: theme.colorScheme.primary.withOpacity(0.9),
        ),
      ),
    );
  }
}
