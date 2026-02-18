import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/seller_provider.dart';
import '../models/clothing_item.dart'; // [FIX]
import '../ui/components/premium_card.dart';
import '../ui/components/section_header.dart';
import 'dart:convert';
import '../ui/components/action_button.dart';
import '../services/visual_search_service.dart';
import '../l10n/app_localizations.dart'; // [FIX] Added import

class VogueAddProductScreen extends StatefulWidget {
  static const route = '/vogue-seller/add-product';

  final ClothingItem? product; // [FIX]

  const VogueAddProductScreen({super.key, this.product});

  @override
  State<VogueAddProductScreen> createState() => _VogueAddProductScreenState();
}

class _VogueAddProductScreenState extends State<VogueAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  
  String? _imagePath;
  String? _selectedStoreId;

  // Auto-fill state
  bool _isAutoTagging = false;
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  final List<String> _categories = [
    'top', 'bottom', 'outerwear', 'dress', 'shoes', 'accessory', 'hat', 'bag', 'other'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _categoryCtrl.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    
    if (xFile != null) {
      setState(() {
         _imagePath = xFile.path;
         _isAutoTagging = true;
      });

      // Auto-Tagging Logic
      try {
         final bytes = await xFile.readAsBytes();
         final base64Image = base64Encode(bytes);
         
         // [NEW] Get current locale
         final localeCode = Localizations.localeOf(context).languageCode;

         final service = VisualSearchService();
         final result = await service.autoTagClothing(base64Image, locale: localeCode);
         
         if (!mounted) return;
         
         setState(() {
           // Auto-fill Name
           if (_nameCtrl.text.isEmpty && result.name.isNotEmpty) {
             _nameCtrl.text = result.name;
           }
           
           // Auto-fill Category
           if (_categoryCtrl.text.isEmpty && result.category.isNotEmpty) {
             _categoryCtrl.text = result.category;
           }
           
           // Auto-fill Description (combine color, style, season)
           if (_descCtrl.text.isEmpty) {
             final descParts = [
               if (result.color.isNotEmpty) 'Color: ${result.color}',
               if (result.style.isNotEmpty) 'Style: ${result.style.join(", ")}',
               if (result.season.isNotEmpty) 'Season: ${result.season.join(", ")}',
               if (result.tags.isNotEmpty) 'Tags: ${result.tags.join(", ")}',
             ];
             _descCtrl.text = descParts.join("\n");
           }

           // Add Tags
           for (var tag in result.tags) {
             if (!_tags.contains(tag)) _tags.add(tag);
           }
           if (result.color.isNotEmpty && !_tags.contains(result.color)) {
              _tags.add(result.color);
           }
         });
         
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(context.tr('seller_msg_ai_success'))),
         );

      } catch (e) {
        debugPrint("Store Auto-tag error: $e");
      } finally {
        if(mounted) setState(() => _isAutoTagging = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('seller_msg_select_image'))),
      );
      return;
    }

    final seller = context.read<SellerProvider>();
    
    // Auto-select first store if none selected
    if (_selectedStoreId == null && seller.stores.isNotEmpty) {
      _selectedStoreId = seller.stores.first.id;
    }

    // If still no store, show error
    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('seller_msg_create_store'))),
      );
      return;
    }

    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final stock = int.tryParse(_stockCtrl.text) ?? 0;

    final newProduct = ClothingItem(
      id: widget.product?.id ?? seller.generateId(),
      storeId: _selectedStoreId!,
      name: _nameCtrl.text,
      category: _categoryCtrl.text,
      imagePath: _imagePath!,
      price: price,
      stock: stock,
      description: _descCtrl.text,
      isAvailable: true,
      sellerId: seller.sellerId,
      // Store tags and colors if model supports it (it does now)
      tags: _tags,
      colors: [], // extracted into description for now, or could parse
    );

    if (widget.product != null) {
      await seller.updateProduct(newProduct);
    } else {
      await seller.addProduct(newProduct);
    }

    if (mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seller = context.watch<SellerProvider>();
    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
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
                        title: isEditing ? 'Редактировать товар' : 'Новый товар',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Image Picker
                Center(
                  child: GestureDetector(
                    onTap: _isAutoTagging ? null : _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _imagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(
                                    File(_imagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 40,
                                      color: theme.colorScheme.primary.withOpacity(0.4),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      context.tr('seller_product_image_placeholder'),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                        ),
                        if (_isAutoTagging)
                           Positioned.fill(
                             child: Container(
                               decoration: BoxDecoration(
                                 color: Colors.black.withOpacity(0.4),
                                 borderRadius: BorderRadius.circular(20),
                               ),
                               child: const Center(
                                 child: CircularProgressIndicator(color: Colors.white),
                               ),
                             ),
                           ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Fields
                PremiumCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameCtrl,
                        label: context.tr('seller_label_name'),
                        icon: Icons.tag,
                        validator: (v) => v?.isEmpty == true ? context.tr('seller_validator_name') : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descCtrl,
                        label: context.tr('seller_label_desc'),
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _priceCtrl,
                              label: context.tr('seller_label_price'),
                              icon: Icons.attach_money,
                              keyboardType: TextInputType.number,
                              validator: (v) => v?.isEmpty == true ? context.tr('seller_validator_price') : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _stockCtrl,
                              label: context.tr('seller_label_stock'),
                              icon: Icons.inventory_2_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) => v?.isEmpty == true ? context.tr('seller_validator_stock') : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _categoryCtrl,
                        label: context.tr('seller_label_category'),
                        icon: Icons.category_outlined,
                      ),
                      const SizedBox(height: 16),
                      
                      // Tags Field
                      TextFormField(
                        controller: _tagController,
                        onFieldSubmitted: _addTag,
                        decoration: InputDecoration(
                          labelText: context.tr('seller_label_tags'),
                          prefixIcon: const Icon(Icons.style, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _addTag(_tagController.text),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.05),
                        ),
                      ),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(() => _tags.remove(tag)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          )).toList(),
                        ),
                      ],

                      const SizedBox(height: 24),
                      
                      // Store Selector
                      DropdownButtonFormField<String>(
                        value: _selectedStoreId,
                        decoration: InputDecoration(
                          labelText: context.tr('seller_label_store'),
                          prefixIcon: const Icon(Icons.store_mall_directory_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                          ),
                        ),
                        items: seller.stores.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedStoreId = val),
                        validator: (v) => v == null ? context.tr('seller_validator_store') : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                ActionButton(
                  label: isEditing ? context.tr('seller_btn_save_edit') : context.tr('seller_btn_save_new'),
                  onPressed: _isAutoTagging ? null : _save,
                  icon: isEditing ? Icons.save : Icons.add,
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
      ),
    );
  }
}
