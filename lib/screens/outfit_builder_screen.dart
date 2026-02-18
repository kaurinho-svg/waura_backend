import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart'; // Added for PointerScrollEvent
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart'; 
import 'package:image/image.dart' as img; // Trim logic

import '../providers/catalog_provider.dart'; 
import '../ui/layouts/luxe_scaffold.dart';
import '../l10n/app_localizations.dart'; // [NEW]
import 'vogue_try_on_screen.dart';

// Robust data model for sticker-like items
class OutfitItem {
  final String id;
  final ImageProvider image;
  
  // Transform properties
  double x;
  double y;
  double scale;
  double rotation;
  
  OutfitItem({
    required this.id,
    required this.image,
    this.x = 100.0,
    this.y = 100.0,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

class OutfitBuilderScreen extends StatefulWidget {
  static const route = '/outfit-builder';

  const OutfitBuilderScreen({super.key});

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<OutfitItem> _items = [];
  String? _selectedItemId;
  final ImagePicker _picker = ImagePicker();

  void _addItem(ImageProvider image) {
    setState(() {
      final id = DateTime.now().toIso8601String();
      // Add to center of screen usually, here just offset
      _items.add(OutfitItem(id: id, image: image, x: 150, y: 150, scale: 0.5));
      _selectedItemId = id;
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      _addItem(MemoryImage(bytes));
    }
  }

  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
      if (_selectedItemId == id) {
        _selectedItemId = null;
      }
    });
  }

  Future<void> _saveOrTryOn({required bool tryOn}) async {
    try {
      setState(() { _selectedItemId = null; });
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('outfit_error_capture'))));
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 4.0); // BUMP RESOLUTION
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      Uint8List pngBytes = byteData.buffer.asUint8List();

      try {
        final decoded = img.decodePng(pngBytes);
        if (decoded != null) {
          final trimmed = img.trim(decoded, mode: img.TrimMode.topLeftColor);
          pngBytes = Uint8List.fromList(img.encodePng(trimmed));
        }
      } catch (e) { print(e); }
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/outfit_collage_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);

      if (tryOn) {
        if (!mounted) return;
        Navigator.pushNamed(
          context, 
          VogueTryOnScreen.route,
          arguments: {'clothingFile': file}, 
        );
      } else {
        await Share.shareXFiles([XFile(file.path)], text: context.tr('outfit_share_text'));
      }

    } catch (e) {
      print('Error: $e');
    }
  }

  void _updateItem(String id, {double? x, double? y, double? scale, double? rotation}) {
    setState(() {
       final idx = _items.indexWhere((i) => i.id == id);
       if (idx != -1) {
         if (x != null) _items[idx].x = x;
         if (y != null) _items[idx].y = y;
         if (scale != null) _items[idx].scale = scale;
         if (rotation != null) _items[idx].rotation = rotation;
       }
    });
  }

  void _showCatalogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      context.tr('outfit_catalog_title'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Consumer<CatalogProvider>(
                      builder: (context, provider, child) {
                        final items = provider.items;
                        if (items.isEmpty) {
                          return Center(child: Text(context.tr('outfit_catalog_empty')));
                        }
                        return GridView.builder(
                          controller: controller, // important for draggable sheet
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            ImageProvider? imgProv;
                            
                            if (item.isNetwork) {
                              imgProv = NetworkImage(item.imagePath); 
                            } else {
                              imgProv = FileImage(File(item.imagePath));
                            }
                            
                            // Fallback if network logic is simple string
                            if (item.imagePath.startsWith('http')) {
                               imgProv = NetworkImage(item.imagePath);
                            } else {
                               imgProv = FileImage(File(item.imagePath));
                            }

                            return GestureDetector(
                              onTap: () {
                                _addItem(imgProv!);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image(
                                    image: imgProv!, 
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LuxeScaffold(
      title: context.tr('outfit_title'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Catalog Button
                 IconButton.filledTonal(
                  onPressed: _showCatalogSheet,
                  icon: const Icon(Icons.inventory_2_outlined),
                  tooltip: context.tr('outfit_btn_catalog'),
                ),
                const SizedBox(width: 8),
                // Gallery Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text(context.tr('outfit_btn_gallery'), overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                // Actions
                IconButton(
                    onPressed: () => _saveOrTryOn(tryOn: false), 
                    icon: const Icon(Icons.share),
                    tooltip: context.tr('outfit_tooltip_share'),
                ),
                IconButton.filled(
                  onPressed: () => _saveOrTryOn(tryOn: true),
                  icon: const Icon(Icons.checkroom),
                  tooltip: context.tr('outfit_tooltip_try_on'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
                width: double.infinity,
                height: double.infinity,
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white, // Keep visual white background
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Listener( // [NEW] Catch Mouse Wheel
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent && _selectedItemId != null) {
                         final item = _items.firstWhere((i) => i.id == _selectedItemId);
                         // Scroll down (positive) -> Zoom out
                         // Scroll up (negative) -> Zoom in
                         final double scaleChange = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
                         _updateItem(item.id, scale: item.scale * scaleChange);
                      }
                    },
                    child: RepaintBoundary( 
                      key: _canvasKey,
                      child: Container(
                        // [FIX] Transparent background for RepaintBoundary so Trim works
                        // But we want user to see "Canvas". 
                        // The parent Container (lines above) provides white background.
                        // This internal container will be transparent.
                        color: Colors.transparent, 
                        child: Stack(
                          children: [
                           // [FIX] Tap background to deselect
                           Positioned.fill(
                             child: GestureDetector(
                               onTap: () {
                                 setState(() { _selectedItemId = null; });
                               },
                               behavior: HitTestBehavior.translucent,
                               child: Container(),
                             ),
                           ),

                           if (_items.isEmpty)
                             Center(
                               child: GestureDetector(
                                 onTap: _showCatalogSheet,
                                 child: Column(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey[400]),
                                     const SizedBox(height: 10),
                                     Text(
                                       context.tr('outfit_empty_text'),
                                       style: TextStyle(color: Colors.grey[500]),
                                       textAlign: TextAlign.center,
                                     ),
                                   ],
                                 ),
                               ),
                             ),
                           ..._items.map((item) {
                             return Positioned(
                               left: item.x,
                               top: item.y,
                               child: GestureDetector(
                                 onScaleStart: (details) {
                                   setState(() { _selectedItemId = item.id; });
                                 },
                                 onScaleUpdate: (details) {
                                   if (_selectedItemId != item.id) return;
                                   
                                   if (details.pointerCount == 1) {
                                      _updateItem(item.id, 
                                        x: item.x + details.focalPointDelta.dx,
                                        y: item.y + details.focalPointDelta.dy
                                      );
                                   } 
                                   else {
                                     _updateItem(item.id,
                                        scale: item.scale * details.scale,
                                        rotation: item.rotation + details.rotation
                                     );
                                   }
                                 },
                                 onTap: () => setState(() { _selectedItemId = item.id; }),
                                 child: Transform(
                                   transform: Matrix4.identity()
                                     ..rotateZ(item.rotation)
                                     ..scale(item.scale),
                                   alignment: Alignment.center,
                                   child: Stack(
                                     clipBehavior: Clip.none,
                                     children: [
                                       Image(image: item.image, width: 200, fit: BoxFit.contain), 
                                       if (_selectedItemId == item.id)
                                          Positioned(
                                            top: -20, // [FIX] Bigger hit area
                                            right: -20,
                                            child: GestureDetector(
                                              onTap: () => _removeItem(item.id),
                                              child:Container( // [FIX] Visible container for hit test
                                                padding: const EdgeInsets.all(8), // touch padding
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.transparent, 
                                                ),
                                                child: const CircleAvatar(
                                                  radius: 16, // [FIX] Bigger visual
                                                  backgroundColor: Colors.red,
                                                  child: Icon(Icons.close, size: 20, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (_selectedItemId == item.id)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(color: const Color.fromARGB(255, 33, 150, 243), width: 2),
                                              ),
                                            ),
                                          )
                                     ],
                                   ),
                                 ),
                               ),
                             );
                           }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
