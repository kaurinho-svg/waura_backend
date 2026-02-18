import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For Blur
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../ui/layouts/luxe_scaffold.dart';
import '../providers/style_consultant_provider.dart';
import '../widgets/consultant_message_bubble.dart';
import '../widgets/quick_question_chips.dart';
import '../ui/components/typing_indicator.dart'; // [NEW]
import '../l10n/app_localizations.dart'; // [NEW]
import '../config/app_config.dart'; // [NEW]

/// Экран AI-консультанта по стилю (VOGUE Style)
class StyleConsultantScreen extends StatefulWidget {
  static const route = '/style-consultant';
  final bool isRoot;

  const StyleConsultantScreen({
    super.key,
    this.isRoot = false,
  });

  @override
  State<StyleConsultantScreen> createState() => _StyleConsultantScreenState();
}

class _StyleConsultantScreenState extends State<StyleConsultantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isInitialized = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _initializeConsultant();
  }

  Future<void> _initializeConsultant() async {
    final consultant = context.read<StyleConsultantProvider>();
    if (!consultant.isInitialized) {
      await consultant.initialize();
    }
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final consultant = context.read<StyleConsultantProvider>();
    
    // Send with image if selected
    if (_selectedImage != null) {
      consultant.askQuestionWithImage(
        text.isEmpty ? '' : text,
        _selectedImage!.path,
        context,
      );
      setState(() {
        _selectedImage = null;
      });
    } else {
      consultant.askQuestion(text, context);
    }
    
    _controller.clear();
    _scrollToBottom();
  }

  void _handleQuickQuestion(String question) {
    final consultant = context.read<StyleConsultantProvider>();
    consultant.askQuestion(question, context);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60, // Extra space
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.primary;

    if (!_isInitialized) {
      return LuxeScaffold(
        title: 'AI Stylist',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return LuxeScaffold(
      title: context.tr('consultant_title'),
      showBack: !widget.isRoot,
      child: Stack(
        children: [
          // Background Pattern (Optional)
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Image.asset(
                'assets/images/pattern_vogue.png', // Fallback if exists, else ignores
                repeat: ImageRepeat.repeat,
                errorBuilder: (_,__,___) => const SizedBox(),
              ),
            ),
          ),
          
          Column(
            children: [

              
              // Disclaimer

              _buildDisclaimer(theme),

              // Chat List
              Expanded(
                child: Consumer<StyleConsultantProvider>(
                  builder: (context, consultant, _) {
                    if (consultant.messages.isEmpty) {
                         // Empty State
                         return Center(
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Icon(Icons.auto_awesome, size: 48, color: goldColor.withOpacity(0.5)),
                               const SizedBox(height: 16),
                               Text(
                                 context.tr('consultant_welcome'),
                                 textAlign: TextAlign.center,
                                 style: theme.textTheme.headlineSmall?.copyWith(
                                   fontFamily: 'Playfair Display',
                                   color: theme.colorScheme.onSurface.withOpacity(0.7),
                                 ),
                               ),
                             ],
                           ),
                         );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 16, bottom: 160), // Space for input (Quick Chips + Text)
                      itemCount: consultant.messages.length + (consultant.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == consultant.messages.length) {
                          // Loading Indicator
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                               crossAxisAlignment: CrossAxisAlignment.end,
                               children: [
                                 Container(width: 32, height: 32, decoration: BoxDecoration(color: goldColor, shape: BoxShape.circle), child: const Center(child: Text("V", style: TextStyle(fontWeight: FontWeight.bold)))),
                                 const SizedBox(width: 12),
                                 TypingIndicator(color: goldColor),
                               ],
                            ),
                          );
                        }

                        final message = consultant.messages[index];
                        return ConsultantMessageBubble(message: message);
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // Floating Bottom Input with Quick Chips
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
               child: BackdropFilter(
                 filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                 child: Container(
                   padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 12),
                   decoration: BoxDecoration(
                     color: theme.scaffoldBackgroundColor.withOpacity(0.9), // Match theme background
                     border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
                   ),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       // Quick Action Chips (Above Input)
                       SizedBox(
                         height: 40,
                         child: QuickQuestionChips(
                           onQuestionSelected: _handleQuickQuestion,
                         ),
                       ),
                       const SizedBox(height: 12),
                       
 // Замените строки 238-276 в style_consultant_screen.dart этим кодом:
                        // Input Row
                        Row(
                          children: [
                            // Image Picker Button
                            IconButton(
                              onPressed: _pickImage,
                              icon: Icon(
                                Icons.image_outlined,
                                color: _selectedImage != null 
                                  ? goldColor 
                                  : theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                              tooltip: 'Прикрепить изображение',
                            ),
                            
                            // Input Field with Image Preview
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _selectedImage != null
                                      ? goldColor.withOpacity(0.5)
                                      : theme.colorScheme.outline.withOpacity(0.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Image Preview
                                    if (_selectedImage != null) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.file(
                                                _selectedImage!,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: -4,
                                              right: -4,
                                              child: IconButton(
                                                icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                                onPressed: () => setState(() => _selectedImage = null),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // Text Input
                                    Expanded(
                                      child: TextField(
                                        controller: _controller,
                                        maxLines: 1,
                                        style: theme.textTheme.bodyMedium,
                                        decoration: InputDecoration(
                                          hintText: _selectedImage != null
                                            ? 'Добавьте комментарий (необязательно)...'
                                            : context.tr('consultant_input_hint'),
                                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                             color: theme.colorScheme.onSurface.withOpacity(0.5)
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                        ),
                                        textInputAction: TextInputAction.send,
                                        onSubmitted: (_) => _sendMessage(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Consumer<StyleConsultantProvider>(
                             builder: (context, consultant, _) {
                               return Container(
                                 decoration: BoxDecoration(
                                    color: Colors.black, // High contrast button
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                                 ),
                                 child: IconButton(
                                   onPressed: consultant.isLoading ? null : _sendMessage,
                                   icon: const Icon(Icons.arrow_upward, color: Colors.white),
                                   tooltip: context.tr('consultant_send_tooltip'),
                                 ),
                               );
                             },
                           ),
                         ],
                       ),
                     ],
                   ),
                 ),
               ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(ThemeData theme) {
    // Elegant minimalist disclaimer
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Center(
        child: Text(
          context.tr('consultant_disclaimer'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            letterSpacing: 1.5,
            fontSize: 9,
          ),
        ),
      ),
    );
  }
}
