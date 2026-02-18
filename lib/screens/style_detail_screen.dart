import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/mock_styles.dart';
import '../ui/layouts/luxe_scaffold.dart';
import 'vogue_try_on_screen.dart'; // Updated
import 'dart:convert';
import '../services/visual_search_service.dart';
import '../ui/sheets/product_match_sheet.dart';
import '../ui/components/scanner_overlay.dart';

class StyleDetailScreen extends StatefulWidget {
  final StyleInspiration item;

  const StyleDetailScreen({super.key, required this.item});

  @override
  State<StyleDetailScreen> createState() => _StyleDetailScreenState();
}

class _StyleDetailScreenState extends State<StyleDetailScreen> {
  bool _isLoading = false;

  Future<void> _tryOnLook() async {
    setState(() { _isLoading = true; });
    try {
      // 1. Download image to temp file
      final response = await http.get(Uri.parse(widget.item.imageUrl));
      if (response.statusCode != 200) throw Exception("Failed to download image");

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/style_tryon_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);

      if (!mounted) return;

      // 2. Navigate to VogueTryOnScreen
      Navigator.pushNamed(
        context, 
        VogueTryOnScreen.route,
        arguments: {'clothingFile': file}, 
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  bool _isScanning = false; // Separate state for visual search

  Future<void> _shopTheLook() async {
    setState(() => _isScanning = true);
    try {
       // 1. Download image
       final response = await http.get(Uri.parse(widget.item.imageUrl));
       if (response.statusCode != 200) throw Exception('Failed to download image');
       
       // 2. Convert to Base64
       final base64Image = base64Encode(response.bodyBytes);
       
       // 3. Analyze
       final service = VisualSearchService();
       final items = await service.analyzeImage(base64Image);
       
       if (!mounted) return;
       setState(() => _isScanning = false);
       
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
         setState(() => _isScanning = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка поиска: $e')));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 28),
            onPressed: (_isLoading || _isScanning) ? null : _shopTheLook,
            tooltip: 'Найти похожие вещи',
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
               Share.share("Check out this style: ${widget.item.title} ${widget.item.imageUrl}");
            },
          )
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Blurred Background (for Desktop fill)
          CachedNetworkImage(
            imageUrl: widget.item.imageUrl,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.5),
            colorBlendMode: BlendMode.darken,
          ),
          
          // 2. BackdropFilter for blur effect
          Positioned.fill(
             child: BackdropFilter(
               filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
               child: Container(color: Colors.transparent),
             ),
          ),

          // 3. Main Image wrapped with Scanner
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // If screen is wider than tall (Desktop), use contain to show full outfit
                final bool isDesktop = constraints.maxWidth > constraints.maxHeight;
                return ScannerOverlay(
                  isScanning: _isScanning,
                  child: CachedNetworkImage(
                    imageUrl: widget.item.imageUrl,
                    fit: isDesktop ? BoxFit.contain : BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_,__) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    errorWidget: (_,__,___) => const Center(child: Icon(Icons.error, color: Colors.white)),
                  ),
                );
              }
            ),
          ),
          
          // Gradient Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 100, bottom: 40, left: 20, right: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: widget.item.tags.map((tag) => 
                      Chip(
                        label: Text(tag, style: const TextStyle(color: Colors.black)),
                        backgroundColor: Colors.white.withOpacity(0.9),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )
                    ).toList(),
                  ),
                  const SizedBox(height: 30),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _isScanning) ? null : _tryOnLook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.checkroom),
                      label: Text(
                        _isLoading ? "Загрузка..." : "Примерить этот образ",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20), // Bottom padding
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
