import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart'; // ✅
import '../data/mock_styles.dart';
import '../ui/layouts/luxe_scaffold.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/app_user.dart';
import '../l10n/app_localizations.dart'; // [NEW]
import 'style_detail_screen.dart';

import '../services/style_search_api.dart'; // Import API
import 'style_search_screen.dart'; // Visual Search

class InspirationFeedScreen extends StatefulWidget {
  static const route = '/inspiration-feed';

  const InspirationFeedScreen({
    super.key,
    this.isRoot = false,
  });

  final bool isRoot;

  @override
  State<InspirationFeedScreen> createState() => _InspirationFeedScreenState();
}

class _InspirationFeedScreenState extends State<InspirationFeedScreen> {
  String _selectedCategory = 'All';
  late bool _isFemale;
  
  // Inspiration mode
  List<StyleInspiration> _items = [];
  bool _isLoading = false;

  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _isFemale = user?.gender == Gender.female;
    _loadStyles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _changeCategory(String newCat) {
    if (_selectedCategory == newCat) return;
    setState(() { _selectedCategory = newCat; });
    _loadStyles();
  }
  
  void _toggleGender(bool isFemale) {
    if (_isFemale == isFemale) return;
    setState(() { 
      _isFemale = isFemale;
    });
    // Reload with current category or search
    if (_searchController.text.isNotEmpty) {
      _loadStyles(customQuery: _searchController.text);
    } else {
      _loadStyles();
    }
  }

  Future<void> _loadStyles({String? customQuery}) async {
    setState(() { _isLoading = true; });
    
    if (_selectedCategory == 'Favorites') {
       final favs = context.read<FavoritesProvider>().items;
       setState(() {
         _items = favs; // Show local favorites
         _isLoading = false;
       });
       return;
    }
    
    String queryCategory = customQuery ?? (_selectedCategory == 'All' ? 'Trending' : _selectedCategory);
    final genderStr = _isFemale ? 'female' : 'male';
    
    try {
      final results = await StyleSearchApi.searchStyles(
        gender: genderStr,
        category: queryCategory,
      );
      
      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading internet styles: $e");
      if (mounted) {
         // Fallback to mock data if error
         final fallback = _isFemale ? mockFemaleStyles : mockMaleStyles;
         final filtered = _selectedCategory == 'All' 
             ? fallback 
             : fallback.where((i) => i.category == _selectedCategory).toList();
             
         setState(() {
           _items = filtered;
           _isLoading = false;
         });
         
         String msg = context.tr('inspiration_offline_msg');
         final eStr = e.toString();
         if (eStr.contains('502') || eStr.contains('503') || eStr.contains('Timeout')) {
           msg = "${context.tr('inspiration_offline_msg')} (Server waking up)";
         }

         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(msg))
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories = [
      'Favorites', 'All', 'Business', 'Casual', 'Smart Casual', 'Streetwear', 'Sport', 
      'Minimal', 'Old Money', 'Grunge', 'Boho', 'Military', 'Event'
    ];

    return LuxeScaffold(
      title: context.tr('inspiration_title'),
      showBack: !widget.isRoot,
      actions: [
        // GENDER TOGGLE
        Container(
          height: 36,
          margin: const EdgeInsets.only(right: 16, top: 10),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GenderBtn(
                label: context.tr('inspiration_gender_m'), 
                isSelected: !_isFemale, 
                onTap: () => _toggleGender(false),
              ),
              _GenderBtn(
                label: context.tr('inspiration_gender_f'), 
                isSelected: _isFemale, 
                onTap: () => _toggleGender(true),
              ),
            ],
          ),
        )
      ],
      child: Column(
        children: [
          // Search Bar & Filter Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Field with Camera Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: context.tr('inspiration_search_hint'),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            setState(() { 
                              _selectedCategory = 'Custom'; // Mark as custom
                            });
                            _loadStyles(customQuery: value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Camera Button for Visual Search
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: () => Navigator.pushNamed(context, StyleSearchScreen.route),
                        tooltip: context.tr('inspiration_shop_look'),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: categories.map((cat) {
                     final isSelected = _selectedCategory == cat;
                     
                     // Transform category name to translated version
                     // cat_Favorites, cat_All, etc.
                     String label;
                     if (cat == 'Custom') {
                       label = cat;
                     } else {
                        // cat e.g. "Smart Casual" -> "smart_casual"
                        final key = 'cat_${cat.toLowerCase().replaceAll(' ', '_')}';
                        label = context.tr(key);
                        // If translation missing (fallback to key), use cat
                        if (label == key) label = cat;
                     }

                     return Padding(
                       padding: const EdgeInsets.only(right: 8),
                       child: ChoiceChip(
                         label: Text(label),
                         selected: isSelected,
                         onSelected: (bool selected) {
                           if (selected) {
                             _searchController.clear(); // Clear text search
                             _changeCategory(cat);
                           }
                         },
                         selectedColor: Colors.black,
                         labelStyle: TextStyle(
                           color: isSelected ? Colors.white : Colors.black,
                           fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                         ),
                         backgroundColor: Colors.grey[100],
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                         showCheckmark: false,
                       ),
                     );
                  }).toList(),
                ),
              ),
            ],
          ),
          
          // Grid
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : _items.isEmpty 
                  ? Center(child: Text(context.tr('inspiration_empty')))
                  : RefreshIndicator(
                      onRefresh: () => _loadStyles(customQuery: _searchController.text.isNotEmpty ? _searchController.text : null),
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        physics: const AlwaysScrollableScrollPhysics(), // Ensure scroll for refresh
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65, 
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _StyleCard(item: item);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  final StyleInspiration item;

  const _StyleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    // 1. Consume FavoritesProvider
    final favs = context.watch<FavoritesProvider>();
    final isLiked = favs.isFavorite(item.imageUrl);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => StyleDetailScreen(item: item)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                httpHeaders: const {
                  'User-Agent': 
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                },
                placeholder: (context, url) => Container(color: Colors.grey[100]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              // Gradient Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                ),
              ),
              // Heart Button (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => favs.toggleFavorite(item),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Text
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4), 
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderBtn({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
