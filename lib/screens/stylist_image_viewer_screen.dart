import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../ui/layouts/luxe_scaffold.dart';
import '../providers/catalog_provider.dart';
import '../models/clothing_item.dart';
import 'vogue_try_on_screen.dart';
import 'dart:convert'; // For base64
import '../services/visual_search_service.dart';
import '../ui/sheets/product_match_sheet.dart';
import '../ui/components/scanner_overlay.dart';

class StylistImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String? title;

  const StylistImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.title,
  });

  @override
  State<StylistImageViewerScreen> createState() => _StylistImageViewerScreenState();
}

class _StylistImageViewerScreenState extends State<StylistImageViewerScreen> {
  bool _isSaving = false;

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    try {
      // Download image to temp file
      final directory = await getTemporaryDirectory();
      final fileName = 'outfit_assistant_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${directory.path}/$fileName');
      
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        
        // Save to gallery using gal
        await Gal.putImage(file.path);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Сохранено в галерею! 💾')),
           );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveToWardrobe() async {
    // Add to 'Inspiration' category
    // This requires simple Mock logic if backend doesn't support generic URLs yet, 
    // but CatalogProvider usually deals with File paths.
    // For now, we will just show a "Not implemented" or try to download and add.
    
    // Better strategy: Navigate to AddProductScreen pre-filled? 
    // Or just precise logic:
    setState(() => _isSaving = true);
    
    try {
       // Download to app storage
       final directory = await getApplicationDocumentsDirectory();
       final fileName = 'inspiration_${DateTime.now().millisecondsSinceEpoch}.jpg';
       final file = File('${directory.path}/$fileName');
       
       final response = await http.get(Uri.parse(widget.imageUrl));
       await file.writeAsBytes(response.bodyBytes);

       if (mounted) {
         final catalog = context.read<CatalogProvider>();
         catalog.addItem(ClothingItem(
           id: DateTime.now().millisecondsSinceEpoch.toString(),
           name: widget.title ?? 'Idea from Stylist',
           category: 'Inspiration',
           imagePath: file.path, 
           colors: [],
         ));
         
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Добавлено в гардероб! ✨')),
         );
       }
    } catch (e) {
       // ...
    } finally {
       if (mounted) setState(() => _isSaving = false);
    }
  }



  bool _isSearching = false; // New state for scanning

  // ... (rest of methods)

  Future<void> _shopTheLook() async {
    setState(() => _isSearching = true); // Start scanning
    
    try {
       // 1. Download image
       final response = await http.get(Uri.parse(widget.imageUrl));
       if (response.statusCode != 200) throw Exception('Failed to download image');
       
       // 2. Convert to Base64
       final base64Image = base64Encode(response.bodyBytes);
       
       // 3. Analyze
       final service = VisualSearchService();
       final items = await service.analyzeImage(base64Image);
       
       if (!mounted) return;
       setState(() => _isSearching = false); // Stop scanning
       
       // 4. Show Sheet
       if (items.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Не удалось определить вещи на фото 😔'))
         );
       } else {
         showModalBottomSheet(
           context: context,
           isScrollControlled: true,
           backgroundColor: Colors.transparent,
           builder: (context) => DraggableScrollableSheet(
             initialChildSize: 0.6,
             minChildSize: 0.4,
             maxChildSize: 0.9,
             builder: (_, controller) => ProductMatchSheet(items: items),
           ),
         );
       }

    } catch (e) {
       if (mounted) {
         setState(() => _isSearching = false);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Ошибка поиска: $e')),
         );
       }
    }
  }

  void _goToTryOn() async {
    // Download file first because TryOn expects a File path or Uploaded File
    setState(() => _isSaving = true);
    try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'tryon_temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${directory.path}/$fileName');
        
        final response = await http.get(Uri.parse(widget.imageUrl));
        await file.writeAsBytes(response.bodyBytes);
        
        if (!mounted) return;
        setState(() => _isSaving = false);

        Navigator.pushNamed(
          context,
          VogueTryOnScreen.route,
          arguments: {
            'garmentPath': file.path,
          },
        );
    } catch (e) {
        if (mounted) setState(() => _isSaving = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error preparing try-on: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(widget.imageUrl),
          ),
        ],
      ),
      body: Stack(
        children: [
          ScannerOverlay(
            isScanning: _isSearching,
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, event) {
                    if (event == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                ),
              ),
            ),
          ),
          
          if (_isSaving)
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Bottom Actions
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   _ActionButton(
                     icon: Icons.save_alt, 
                     label: 'Галерея', 
                     onTap: _saveToGallery
                   ),
                   _ActionButton(
                     icon: Icons.checkroom, 
                     label: 'В гардероб', 
                     onTap: _saveToWardrobe
                   ),
                   _ActionButton(
                     icon: Icons.search, 
                     label: 'Найти', 
                     onTap: _shopTheLook,
                     isPrimary: true,
                   ),
                   _ActionButton(
                     icon: Icons.auto_fix_high, 
                     label: 'Примерить', 
                     onTap: _goToTryOn,
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            color: isPrimary ? Colors.amber : Colors.white,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.amber : Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
