import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/consultant_message.dart';
import 'product_recommendation_card.dart';
import '../screens/stylist_image_viewer_screen.dart';
import '../l10n/app_localizations.dart';

/// Пузырь сообщения в чате (VOGUE Style)
class ConsultantMessageBubble extends StatelessWidget {
  final ConsultantMessage message;

  const ConsultantMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    
    // VOGUE / High Contrast Colors
    final userBgColor = Colors.black; 
    final userTextColor = Colors.white;
    
    final aiBgColor = Colors.white; 
    final aiTextColor = Colors.black;
    final aiBorderColor = const Color(0xFFE0E0E0); 

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // AI Avatar (Left)
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'V',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair Display',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Bubble
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75, 
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? userBgColor : aiBgColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(2),
                      bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(20),
                    ),
                    border: !isUser ? Border.all(color: aiBorderColor, width: 1) : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [NEW] Display user uploaded image
                      if (message.imagePath != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(message.imagePath!),
                              width: 200, 
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                      
                      MarkdownBody(
                        data: (message.source == 'system') 
                            ? (AppLocalizations.of(context)?.translate('consultant_intro') ?? message.text)
                            : message.text,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: theme.textTheme.bodyMedium?.copyWith(
                            color: isUser ? userTextColor : aiTextColor,
                            height: 1.5,
                          ),
                          strong: theme.textTheme.bodyMedium?.copyWith(
                            color: isUser ? userTextColor : theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          h1: theme.textTheme.titleMedium?.copyWith(
                            color: isUser ? userTextColor : theme.colorScheme.primary,
                            fontFamily: 'Playfair Display',
                            fontWeight: FontWeight.bold,
                          ),
                          h2: theme.textTheme.titleSmall?.copyWith(
                             color: isUser ? userTextColor : theme.colorScheme.primary,
                             fontFamily: 'Playfair Display',
                             fontWeight: FontWeight.bold,
                          ),
                          listBullet: theme.textTheme.bodyMedium?.copyWith(
                            color: isUser ? userTextColor : aiTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          _formatTime(message.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: (isUser ? userTextColor : aiTextColor).withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Attachments (Products)
        if (!isUser && message.recommendedProducts.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 60, right: 16, top: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✨ Рекомендации VOGUE:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: message.recommendedProducts.length,
                    itemBuilder: (context, index) {
                      final productId = message.recommendedProducts[index];
                      // Scale down slightly to fit style
                      return Transform.scale(
                        scale: 0.95,
                        alignment: Alignment.topLeft,
                        child: ProductRecommendationCard(productId: productId),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // Attachments (Images)
        if (!isUser && message.generatedImages.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 60, right: 16, top: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Идеи из интернета:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: message.generatedImages.length,
                    itemBuilder: (context, index) {
                      final img = message.generatedImages[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StylistImageViewerScreen(
                                  imageUrl: img['imageUrl'] ?? '',
                                  title: img['title'],
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                              image: DecorationImage(
                                image: NetworkImage(img['imageUrl'] ?? ''),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                 width: double.infinity,
                                 padding: const EdgeInsets.all(4),
                                 decoration: BoxDecoration(
                                   color: Colors.black.withOpacity(0.7),
                                   borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                 ),
                                 child: Text(
                                   img['title'] ?? 'Idea',
                                   style: const TextStyle(color: Colors.white, fontSize: 10),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                   textAlign: TextAlign.center,
                                 ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
