// lib/screens/add_clothing_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert'; // base64

import '../ui/layouts/luxe_scaffold.dart';
import '../models/clothing_item.dart';
import '../providers/catalog_provider.dart';
import '../services/visual_search_service.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class AddClothingScreen extends StatefulWidget {
  static const route = '/add-clothing';

  const AddClothingScreen({super.key});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  final _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  bool _saving = false;

  // Auto-fill state
  bool _isAutoTagging = false;
  String? _category;
  String? _color;
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  final List<String> _categories = [
    'top', 'bottom', 'outerwear', 'dress', 'shoes', 'accessory', 'hat', 'bag', 'other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024, // Optimized for upload
      imageQuality: 85,
    );
    if (picked == null) return;
    
    setState(() {
      _pickedImage = picked;
      _isAutoTagging = true;
    });

    // Auto-Tagging Trigger
    try {
       final bytes = await picked.readAsBytes();
       final base64Image = base64Encode(bytes);
       
       // [NEW] Get current locale
       final localeCode = Localizations.localeOf(context).languageCode;

       final service = VisualSearchService();
       final result = await service.autoTagClothing(base64Image, locale: localeCode);
       
       if (!mounted) return;
       
       setState(() {
         // Auto-fill name if empty
         if (_nameController.text.isEmpty && result.name.isNotEmpty) {
           _nameController.text = result.name;
         }
         
         // Auto-select category
         if (result.category.isNotEmpty && _categories.contains(result.category.toLowerCase())) {
           _category = result.category.toLowerCase();
         }
         
         // Auto-fill color
         if (result.color.isNotEmpty) {
           _color = result.color;
         }
         
         // Add tags
         for (var tag in result.tags) {
           if (!_tags.contains(tag)) {
             _tags.add(tag);
           }
         }
         // Add style/season as tags too
         for (var s in result.style) {
            if (!_tags.contains(s)) _tags.add(s);
         }
         for (var s in result.season) {
            if (!_tags.contains(s)) _tags.add(s);
         }
       });
       
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(context.tr('add_clothing_msg_ai_success'))),
       );
    } catch (e) {
      debugPrint("Auto-tag error: $e");
    } finally {
      if (mounted) setState(() => _isAutoTagging = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('add_clothing_msg_validation'))),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final catalog = context.read<CatalogProvider>();
      
      // Use the wrapper method which handles File creation and upload
      await catalog.addLocalFileItem(
        name: name,
        imagePath: _pickedImage!.path,
        category: _category ?? 'other',
        tags: _tags,
        // color logic can be expanded later if needed
      );

      if (!mounted) return;
      
      setState(() => _saving = false);
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('add_clothing_msg_success'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    }
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _tagController.clear();
      });
    }
  }

  Widget _buildImagePreview(ThemeData theme) {
    final gold = theme.colorScheme.secondary;

    if(_pickedImage != null) {
        return Stack(
          children: [
            Container(
              height: 280,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (theme.cardTheme.color ?? theme.colorScheme.surface).withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: gold.withOpacity(0.25)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: Colors.white.withOpacity(0.20),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: Image.file(File(_pickedImage!.path)),
                  ),
                ),
              ),
            ),
            if (_isAutoTagging)
               Positioned.fill(
                 child: Container(
                   decoration: BoxDecoration(
                     color: Colors.black.withOpacity(0.3),
                     borderRadius: BorderRadius.circular(22),
                   ),
                   child: Center(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const CircularProgressIndicator(color: Colors.white),
                         const SizedBox(height: 12),
                          Text(
                            context.tr('add_clothing_ai_analyzing'), 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                       ],
                     ),
                   ),
                 ),
               ),
          ],
        );
    }
    
    // Empty state
    return Container(
        height: 280,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: gold.withOpacity(0.25)),
          // ...
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 34,
              color: theme.colorScheme.primary.withOpacity(0.9),
            ),
            const SizedBox(height: 10),
            Text(context.tr('add_clothing_pick_image'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(context.tr('add_clothing_ai_hint'), style: theme.textTheme.bodyMedium),
          ],
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return LuxeScaffold(
      title: context.tr('add_clothing_title'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             GestureDetector(
              onTap: _saving || _isAutoTagging ? null : _pickImage,
              child: _buildImagePreview(theme),
            ),
            
            const SizedBox(height: 24),
            
            // Name Field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('add_clothing_label_name'),
                filled: true,
                fillColor: Colors.white.withOpacity(0.35),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: context.tr('add_clothing_label_category'),
                filled: true,
                fillColor: Colors.white.withOpacity(0.35),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: _categories.map((c) {
                String label;
                switch(c) {
                  case 'top': label = context.tr('cat_top'); break;
                  case 'bottom': label = context.tr('cat_bottom'); break;
                  case 'outerwear': label = context.tr('cat_outerwear'); break;
                  case 'dress': label = context.tr('cat_dresses'); break;
                  case 'shoes': label = context.tr('cat_shoes'); break;
                  case 'accessory': label = context.tr('cat_accessory'); break;
                  case 'hat': label = context.tr('cat_hat'); break;
                  case 'bag': label = context.tr('cat_bag'); break;
                  default: label = context.tr('cat_other'); 
                }
                
                return DropdownMenuItem(
                  value: c, 
                  child: Text(label),
                );
              }).toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            
            const SizedBox(height: 16),
            
            // Color Field (Auto-filled but editable)
            TextFormField( // Using TextFormField to easily set initialValue if I wanted, but logic is custom
               key: ValueKey(_color), // Force rebuild if color changes from AI
               initialValue: _color,
               decoration: InputDecoration(
                labelText: context.tr('add_clothing_label_color'),
                filled: true,
                fillColor: Colors.white.withOpacity(0.35),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (v) => _color = v,
            ),
            
            const SizedBox(height: 16),
            
            // Tags Input
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: context.tr('add_clothing_label_tags'),
                filled: true,
                fillColor: Colors.white.withOpacity(0.35),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTag(_tagController.text),
                ),
              ),
              onSubmitted: _addTag,
            ),
            
            if (_tags.isNotEmpty) ...[
               const SizedBox(height: 12),
               Wrap(
                 spacing: 8,
                 runSpacing: 8,
                 children: _tags.map((tag) => Chip(
                   label: Text(tag),
                   deleteIcon: const Icon(Icons.close, size: 16),
                   onDeleted: () => setState(() => _tags.remove(tag)),
                   backgroundColor: gold.withOpacity(0.15),
                 )).toList(),
               ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving || _isAutoTagging ? null : _save,
                style: ElevatedButton.styleFrom(
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   backgroundColor: theme.colorScheme.primary,
                   foregroundColor: Colors.white,
                ),
                child: _saving 
                   ? const CircularProgressIndicator(color: Colors.white) 
                   : Text(context.tr('add_clothing_btn_save'), style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
