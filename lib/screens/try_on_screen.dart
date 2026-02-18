// lib/screens/try_on_screen.dart
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/looks_provider.dart';
import '../services/nano_banana_api.dart'; // ✅ Use Nano Banana API
import '../config/app_config.dart';

class TryOnScreen extends StatefulWidget {
  static const route = '/try-on';

  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  final _picker = ImagePicker();
  final _api = NanoBananaApi(); // ✅ Nano Banana

  XFile? _userImage;
  XFile? _clothingImage;

  Uint8List? _userBytes;
  Uint8List? _clothingBytes;

  bool _loading = false;
  String? _errorText;

  // Optional extra prompting
  final _promptCtrl = TextEditingController();

  String? _resultUrl;
  bool _argsProcessed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsProcessed) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      // Handle File object (from outfit builder)
      final file = args['clothingFile'];
      if (file is File) {
        _loadClothingFromFile(file);
      }
      
      // Handle path string (from catalog)
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
    // Resize to <1.5k px to avoid timeouts on large files
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1512,
      maxHeight: 1512,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _userImage = x;
      _userBytes = bytes;
      _errorText = null;
      _resultUrl = null;
    });
  }

  Future<void> _pickClothing() async {
    // Resize to <1.5k px to avoid timeouts on large files
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1512,
      maxHeight: 1512,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _clothingImage = x;
      _clothingBytes = bytes;
      _errorText = null;
      _resultUrl = null;
    });
  }

  Future<void> _runGenerativeTryOn() async {
    if (_userImage == null || _clothingImage == null) {
      setState(() => _errorText = "Выбери фото человека и фото одежды.");
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
      _resultUrl = null;
    });

    try {
      // 1. Upload Images
      final userUrl = await _api.uploadTemp(_userImage!);
      final clothingUrl = await _api.uploadTemp(_clothingImage!);

      // 2. Generate (Backend handles Auto-Prompting via Gemini)
      // We pass the optional text prompt if user wrote something
      // 2. Generate (Nano Banana)
      final rawResult = await _api.edit(
        user_image_url: userUrl,
        clothing_image_url: clothingUrl,
        style_prompt: _promptCtrl.text.trim(),
        category: null, // Let backend decide or add UI for it if needed
      );

      final result = _api.extractResultImageUrl(rawResult);
      
      if (result == null) {
        throw Exception("Server returned no image url");
      }

      setState(() => _resultUrl = result);
    } catch (e) {
      setState(() => _errorText = "Ошибка генерации: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveLook() async {
    if (_resultUrl == null) return;

    final looks = context.read<LooksProvider>();
    await looks.addLook(
      userImageUrl: _userImage?.path ?? '',
      clothingImageUrl: _clothingImage?.path ?? '',
      resultImageUrl: _resultUrl!,
      prompt: _promptCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Образ сохранён в «Мои образы»")),
    );
  }

  Widget _imageContain(XFile? file, Uint8List? bytes) {
    if (file == null) return const SizedBox.shrink();
    if (bytes != null) return Image.memory(bytes, fit: BoxFit.contain);
    return Image.file(File(file.path), fit: BoxFit.contain);
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paper = const Color(0xFFF5EFE6);
    final ink = const Color(0xFF1A1A1A);
    final gold = const Color(0xFFC9A66B);

    final canTry = !_loading && _userImage != null && _clothingImage != null;

    Widget personCard() => _EditorColumn(
          title: 'Человек',
          gold: gold,
          onAction: _loading ? null : _pickUser,
          actionText: 'Загрузить',
          child: _userImage == null
              ? const _EmptyState(
                  icon: Icons.person_outline,
                  text: 'Ваше фото\n(селфи или в рост)',
                )
              : _ImageSurface(child: _imageContain(_userImage, _userBytes)),
        );


    Widget clothingCard() => _EditorColumn(
          title: 'Одежда',
          gold: gold,
          onAction: _loading ? null : _pickClothing,
          actionText: 'Выбрать',
          child: Column(
            children: [
              Expanded(
                child: _clothingImage == null
                    ? const _EmptyState(
                        icon: Icons.checkroom,
                        text: 'Фото одежды\n(или образа)',
                      )
                    : _ImageSurface(
                        child: _imageContain(
                          _clothingImage,
                          _clothingBytes,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _promptCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Пожелания (необязательно)',
                  hintText: 'Например: "В офисе" или "На пляже"',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.40),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: gold.withOpacity(0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide:
                        BorderSide(color: gold.withOpacity(0.65), width: 1.4),
                  ),
                ),
              ),
            ],
          ),
        );

    Widget resultCard() => _EditorColumn(
          title: 'Результат (Generative)',
          gold: gold,
          onAction: null,
          actionText: _resultUrl == null ? '' : 'Готово',
          child: _resultUrl == null
              ? const _EmptyState(
                  icon: Icons.auto_awesome,
                  text: 'Нейросеть нарисует\nвас в этом образе',
                )
              : _ImageSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.network(
                      _resultUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Не удалось загрузить результат'),
                      ),
                      loadingBuilder: (ctx, child, loading) {
                        if (loading == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
        );

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          color: ink,
        ),
        centerTitle: true,
        title: Text(
          'Виртуальная примерка',
          style: theme.textTheme.titleLarge?.copyWith(
            color: ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          children: [
            if (_errorText != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.withOpacity(0.22)),
                ),
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 900;

                  if (isNarrow) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 360, child: personCard()),
                          const SizedBox(height: 12),
                          SizedBox(height: 430, child: clothingCard()),
                          const SizedBox(height: 12),
                          SizedBox(height: 360, child: resultCard()),
                        ],
                      ),
                    );
                  }

                  return Center(
                    child: SizedBox(
                      width: 1200, // Max total width
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(child: personCard()),
                          _ThinDivider(color: gold),
                          Expanded(child: clothingCard()),
                          _ThinDivider(color: gold),
                          Expanded(child: resultCard()),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: gold.withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canTry ? _runGenerativeTryOn : null,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_loading ? 'Магия...' : 'Сгенерировать'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF141414),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  if (_resultUrl != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saveLook,
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "💡 Совет: Каждый результат уникален. Если получилось неидеально — попробуйте сгенерировать ещё раз!",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6), // Slightly more visible
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  final Color color;
  const _ThinDivider({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: color.withOpacity(0.22),
    );
  }
}

class _EditorColumn extends StatelessWidget {
  final String title;
  final Color gold;
  final VoidCallback? onAction;
  final String actionText;
  final Widget child;

  const _EditorColumn({
    required this.title,
    required this.gold,
    required this.onAction,
    required this.actionText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = const Color(0xFF1A1A1A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (onAction != null)
                TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.upload, size: 18),
                  label: Text(actionText),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ImageSurface extends StatelessWidget {
  final Widget child;
  const _ImageSurface({required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        color: Colors.white.withOpacity(0.18),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(10),
        child: child,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = const Color(0xFF1A1A1A);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: ink.withOpacity(0.75)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: ink.withOpacity(0.75)),
          ),
        ],
      ),
    );
  }
}
