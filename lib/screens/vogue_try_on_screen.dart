import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart'; // [NEW]

import '../providers/looks_provider.dart';
import '../services/nano_banana_api.dart'; // VTON (Step 1)
import '../services/video_generation_service.dart'; // Kling Video (Step 2)
import '../ui/components/premium_card.dart';
import '../ui/components/section_header.dart';
import '../ui/components/action_button.dart';
import '../ui/components/try_on_animation.dart'; 
import '../l10n/app_localizations.dart'; // [NEW] 

/// VOGUE.AI Style Try-On Screen
class VogueTryOnScreen extends StatefulWidget {
  static const route = '/vogue-try-on';

  const VogueTryOnScreen({super.key});

  @override
  State<VogueTryOnScreen> createState() => _VogueTryOnScreenState();
}

class _VogueTryOnScreenState extends State<VogueTryOnScreen> {
  final _picker = ImagePicker();
  final _api = NanoBananaApi();
  final _videoService = VideoGenerationService(); // [NEW]

  XFile? _userImage;
  XFile? _clothingImage;

  Uint8List? _userBytes;
  Uint8List? _clothingBytes;

  bool _loading = false;
  String? _loadingMessage; // [NEW] Custom loading text
  String? _errorText;
  
  String? _resultUrl; // Static Image Result
  String? _resultVideoUrl; // Video Result
  VideoPlayerController? _videoController; // [NEW]

  bool _argsProcessed = false;
  final _promptCtrl = TextEditingController(); 
  
  // Category State
  String _selectedCategory = 'dresses'; // Default to Full Outfit
  
  // Toggle State
  bool _isVideoMode = false; // [NEW] false = Photo, true = Video

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsProcessed) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final file = args['clothingFile'];
      if (file is File) {
        _loadClothingFromFile(file);
      }
      
      final path = args['garmentPath'];
      if (path is String && path.isNotEmpty) {
        _loadClothingFromFile(File(path));
      }
    }
    _argsProcessed = true;
  }

  Future<void> _loadClothingFromFile(File file) async {
    final bytes = await file.readAsBytes();
    final xFile = XFile(file.path);
    setState(() {
      _clothingImage = xFile;
      _clothingBytes = bytes;
      _errorText = null;
    });
  }

  Future<void> _pickUser() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1512,
      maxHeight: 1512,
      imageQuality: 85,
    );
    if (x == null) return;

    final b = await x.readAsBytes();
    setState(() {
      _userImage = x;
      _userBytes = b;
      _errorText = null;
      _resetResults();
    });
  }

  Future<void> _pickClothing() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1512,
      maxHeight: 1512,
      imageQuality: 85,
    );
    if (x == null) return;

    final b = await x.readAsBytes();
    setState(() {
      _clothingImage = x;
      _clothingBytes = b;
      _errorText = null;
      _resetResults();
    });
  }
  
  void _resetResults() {
      _resultUrl = null;
      _resultVideoUrl = null;
      _disposeVideoController();
  }

  void _disposeVideoController() {
      _videoController?.dispose();
      _videoController = null;
  }

  Future<void> _tryOn() async {
    if (_userImage == null || _clothingImage == null) {
      setState(() => _errorText = context.tr('try_on_error_select_both'));
      return;
    }

    setState(() {
      _loading = true;
      _loadingMessage = _isVideoMode ? context.tr('try_on_step_1') : context.tr('try_on_processing');
      _errorText = null;
      _resetResults();
    });

    try {
      // 1. Upload images
      final userUrl = await _api.uploadTemp(_userImage!);
      final clothingUrl = await _api.uploadTemp(_clothingImage!);

      final userPrompt = _promptCtrl.text.trim().isEmpty 
            ? 'Hyper-realistic virtual try-on. The person in the first image is wearing the exact clothing item(s) shown in the second image. Seamless fit, natural lighting. The clothing texture from the reference is preserved. Maintain the person\'s identity.' 
            : _promptCtrl.text.trim();

      // 2. Photo Mode: Use Seedream for static image
      if (!_isVideoMode) {
        final result = await _api.edit(
          user_image_url: userUrl,
          clothing_image_url: clothingUrl,
          style_prompt: userPrompt,
          category: _selectedCategory,
        );

        final staticUrl = _api.extractResultImageUrl(result);
        if (staticUrl == null) throw Exception('Не удалось создать образ (нет картинки)');

        if (!mounted) return;
        setState(() {
          _resultUrl = staticUrl;
          _loading = false;
          _loadingMessage = null;
        });
        return;
      }

      // 3. Video Mode: Direct video try-on using Kling
      if (!mounted) return;
      setState(() {
        _loadingMessage = context.tr('try_on_step_2'); // "Generating video..."
      });

      final videoResult = await _api.videoTryOn(
        user_image_url: userUrl,
        clothing_image_url: clothingUrl,
        style_prompt: userPrompt,
        category: _selectedCategory,
      );

      // Extract video URL from result
      String? videoUrl;
      if (videoResult['video'] != null && videoResult['video']['url'] != null) {
        videoUrl = videoResult['video']['url'].toString();
      } else if (videoResult['url'] != null) {
        videoUrl = videoResult['url'].toString();
      }

      if (videoUrl == null) throw Exception('Video generation failed: no video URL returned');

      // Initialize Video Player
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      controller.setLooping(true);
      controller.play();

      if (!mounted) return;
      setState(() {
        _resultVideoUrl = videoUrl;
        _videoController = controller;
        _loading = false;
        _loadingMessage = null;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString();
        _loading = false;
        _loadingMessage = null;
      });
    }
  }

  Future<void> _saveResult() async {
    // TODO: Handle Video Saving
    if ((!_isVideoMode && _resultUrl == null) || (_isVideoMode && _resultVideoUrl == null)) return;
    if (_userImage == null || _clothingImage == null) return;

    try {
      final lookProvider = context.read<LooksProvider>();
      
      final userUrl = await _api.uploadTemp(_userImage!);
      final clothingUrl = await _api.uploadTemp(_clothingImage!);
      
      await lookProvider.addLook(
        userImageUrl: userUrl,
        clothingImageUrl: clothingUrl,
        resultImageUrl: _resultUrl!,
        prompt: _isVideoMode ? 'Video Try-On' : 'Virtual Try-On',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isVideoMode ? context.tr('try_on_save_video_note') : context.tr('try_on_save_success'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _disposeVideoController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                       Expanded(
                        child: SectionHeader(
                          title: context.tr('try_on_title'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Image Selection Cards
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                        children: [
                          Expanded(
                            child: _ImagePickerCard(
                              title: context.tr('try_on_card_user'),
                              imageBytes: _userBytes,
                              onTap: _pickUser,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ImagePickerCard(
                              title: context.tr('try_on_card_clothing'),
                              imageBytes: _clothingBytes,
                              onTap: _pickClothing,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // [NEW] Category Selection Chips
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCategoryChip(theme, 'Верх', 'upper_body', Icons.checkroom),
                          const SizedBox(width: 12),
                          _buildCategoryChip(theme, 'Низ', 'lower_body', Icons.directions_walk),
                          const SizedBox(width: 12),
                          _buildCategoryChip(theme, 'Весь образ', 'dresses', Icons.accessibility_new),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Mode Switcher (Photo / Video)
                  Center(
                      child: Container(
                          decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  _buildModeBtn(theme, context.tr('try_on_mode_photo'), false),
                                  _buildModeBtn(theme, context.tr('try_on_mode_video'), true),
                              ],
                          ),
                      ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Prompt Input
                  TextField(
                    controller: _promptCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('try_on_input_label'),
                      hintText: context.tr('try_on_input_hint'),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 1,
                  ),

                  const SizedBox(height: 24),

                  // Warning about clothing photo quality
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.secondary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 20,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr('try_on_clothing_warning'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Try-On Button
                  Center(
                    child: ActionButton(
                      label: _loading ? (_loadingMessage ?? context.tr('try_on_processing')) : (_isVideoMode ? context.tr('try_on_btn_create_video') : context.tr('try_on_btn_try_on')),
                      icon: _isVideoMode ? Icons.movie_filter : Icons.checkroom,
                      onPressed: _loading ? null : _tryOn,
                    ),
                  ),
                  
                  if (_loadingMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                          _loadingMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                  ],

                  if (_errorText != null) ...[
                      const SizedBox(height: 16),
                      PremiumCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(_errorText!, style: TextStyle(color: Colors.red)),
                      ),
                  ],

                  // Result Display (Photo or Video)
                  if (!_loading && (_resultUrl != null || _resultVideoUrl != null)) ...[
                    const SizedBox(height: 32),
                     SectionHeader(title: context.tr('try_on_section_result')),
                    const SizedBox(height: 16),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: PremiumCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: SizedBox(
                              height: 500,
                              child: _isVideoMode && _resultVideoUrl != null && _videoController != null
                                  ? AspectRatio(
                                      aspectRatio: _videoController!.value.aspectRatio,
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                            VideoPlayer(_videoController!),
                                            _VideoControls(controller: _videoController!),
                                        ],
                                      ),
                                    )
                                  : Image.network(
                                      _resultUrl!,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (_, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Text(
                                            '${context.tr('my_looks_image_error')}: $error',
                                            style: const TextStyle(color: Colors.red),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ActionButton(
                        label: context.tr('add_clothing_btn_save'), // "Save to Wardrobe" - reusing key
                        icon: Icons.favorite_outline,
                        onPressed: _saveResult,
                      ),
                    ),
                  ],

                  const SizedBox(height: 80), // Bottom nav space
                ],
              ),
            ),
          ),
        ),

        // Animation Overlay
        if (_loading)
          Positioned.fill(
            child: TryOnAnimationOverlay(
              userImageBytes: _userBytes,
              clothingImageBytes: _clothingBytes,
            ),
          ),
      ],
    );
  }
  
  Widget _buildCategoryChip(ThemeData theme, String label, String value, IconData icon) {
    print('Building chip: $label, selected: $_selectedCategory, current: $value');
    final isSelected = _selectedCategory == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 18, 
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedCategory = value;
          });
          print('Category selected: $value');
        }
      },
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
         color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
         fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
  
  Widget _buildModeBtn(ThemeData theme, String text, bool isVideo) {
      final isSelected = _isVideoMode == isVideo;
      return GestureDetector(
          onTap: () => setState(() { 
              _isVideoMode = isVideo; 
              // _resetResults(); // Keep results when switching modes!
          }),
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSelected ? [
                      BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)
                  ] : [],
              ),
              child: Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
              ),
          ),
      );
  }
}

class _VideoControls extends StatelessWidget {
    final VideoPlayerController controller;
    const _VideoControls({required this.controller});
    
    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black54, Colors.transparent])),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    IconButton(
                        icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                        onPressed: () {
                            controller.value.isPlaying ? controller.pause() : controller.play();
                        },
                    ),
                ],
            ),
        );
    }
}

class _ImagePickerCard extends StatelessWidget {
  final String title;
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  const _ImagePickerCard({
    required this.title,
    required this.imageBytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Container(
            // Removed fixed height or made it adaptive?
            // User requested "fully visible". 
            // If we remove height, it depends on parent.
            // Let's use ConstrainedBox with max height but no min, and BoxFit.contain.
            // But if image is tall, it might take too much space.
            // Let's keep a max height but use contain.
            constraints: const BoxConstraints(maxHeight: 300), // Increased from 200 to 300
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      imageBytes!,
                      fit: BoxFit.contain, // [CHANGED] From cover to contain
                      width: double.infinity,
                      // height: double.infinity, // Removed to allow aspect ratio to work within constraint
                    ),
                  )
                : Container(
                    height: 200, // Default height for placeholder
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: theme.colorScheme.primary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('try_on_hint_select'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

