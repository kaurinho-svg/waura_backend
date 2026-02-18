import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/seller_provider.dart';
import '../models/store_model.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section_header.dart';
import '../ui/components/action_button.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class VogueSellerStoresScreen extends StatelessWidget {
  static const route = '/vogue-seller/stores';

  const VogueSellerStoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final seller = context.watch<SellerProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                   IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                   Expanded(
                    child: SectionHeader(
                      title: context.tr('seller_action_my_stores'),
                    ),
                  ),
                   IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddStoreDialog(context),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: seller.stores.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.store_mall_directory_outlined,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr('store_list_empty_title'),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ActionButton(
                            label: context.tr('seller_store_create'),
                            icon: Icons.add_business,
                            onPressed: () => _showAddStoreDialog(context),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: seller.stores.length,
                      itemBuilder: (context, index) {
                        final store = seller.stores[index];
                        return PremiumCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.store,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          store.name,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (store.description.isNotEmpty)
                                          Text(
                                            store.description,
                                            style: theme.textTheme.bodyMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: store.isActive,
                                    activeColor: theme.colorScheme.secondary,
                                    onChanged: (val) {
                                      context.read<SellerProvider>().toggleStoreStatus(store.id);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      store.contactInfo['phone'] ?? context.tr('seller_order_phone'),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStoreDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('seller_store_new_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: context.tr('seller_label_name')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: context.tr('seller_label_desc')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addrCtrl,
                decoration: InputDecoration(labelText: context.tr('seller_order_address')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(labelText: context.tr('seller_order_phone')),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('seller_store_cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;

              final seller = context.read<SellerProvider>();
              final store = StoreModel(
                id: seller.generateId(),
                name: nameCtrl.text,
                description: descCtrl.text,
                // address: addrCtrl.text, // StoreModel doesn't have address
                contactInfo: {'phone': phoneCtrl.text, 'address': addrCtrl.text}, // Put address in contactInfo
                ownerId: seller.sellerId,
                isActive: true,
                url: '', // Required param
              );

              seller.addStore(store);
              Navigator.pop(context);
            },
            child: Text(context.tr('seller_store_create')),
          ),
        ],
      ),
    );
  }
}
