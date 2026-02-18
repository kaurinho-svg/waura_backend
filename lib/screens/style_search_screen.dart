// lib/screens/style_search_screen.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/layouts/luxe_scaffold.dart';
import '../config/app_config.dart';
import '../providers/catalog_provider.dart';
import '../providers/marketplace_provider.dart';
import '../models/clothing_item.dart';
import '../screens/product_detail_screen.dart';
import 'style_search_screen_marketplace_card.dart';

import '../l10n/app_localizations.dart'; // [NEW]

class StyleSearchScreen extends StatefulWidget {
  static const route = '/style-search';
  const StyleSearchScreen({super.key});

  @override
  State<StyleSearchScreen> createState() => _StyleSearchScreenState();
}

class _StyleSearchScreenState extends State<StyleSearchScreen> {
  // ✅ Search-эндпоинты у тебя НЕ под /api/v1, а под корнем: /search/...
  _SearchApi get _api => _SearchApi(baseUrl: AppConfig.backendBaseUrl);
  String get _baseUrl => AppConfig.backendBaseUrl;

  final _queryCtrl = TextEditingController();
  final _internetScroll = ScrollController();
  final _catalogScroll = ScrollController();

  String _query = "";
  int _tabIndex = 1; // 0=магазины, 1=интернет

  // Internet state
  bool _loadingInternet = false;
  bool _loadingMoreInternet = false;
  String? _errInternet;

  final List<_InternetItem> _internetItems = [];
  int _internetTotal = 0;

  int _internetStart = 1;
  final int _internetNum = 10;
  bool _internetHasMore = false;
  int? _internetNextStart;

  // Catalog state
  bool _loadingCatalog = false;
  bool _loadingMoreCatalog = false;
  String? _errCatalog;

  final List<Map<String, dynamic>> _catalogItems = [];
  int _catalogTotal = 0;
  int _catalogPage = 1;
  bool _catalogHasMore = false;

  @override
  void initState() {
    super.initState();

    _initMediaStore();

    _internetScroll.addListener(() {
      if (!_internetHasMore) return;
      if (_loadingInternet || _loadingMoreInternet) return;
      if (_internetScroll.position.pixels >=
          _internetScroll.position.maxScrollExtent - 600) {
        _loadMoreInternet();
      }
    });

    _catalogScroll.addListener(() {
      if (!_catalogHasMore) return;
      if (_loadingCatalog || _loadingMoreCatalog) return;
      if (_catalogScroll.position.pixels >=
          _catalogScroll.position.maxScrollExtent - 600) {
        _loadMoreCatalog();
      }
    });
  }

  Future<void> _initMediaStore() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    try {
      await MediaStore.ensureInitialized();
      // папка приложения (используется как дефолтный relativePath в плагине)
      MediaStore.appFolder = 'Outfit Assistant';
    } catch (_) {
      // если вдруг не Android/нет канала - просто молча игнорим
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _internetScroll.dispose();
    _catalogScroll.dispose();
    super.dispose();
  }

  Future<Uint8List> _downloadImageBytes(String url) async {
    final uri = Uri.parse(url);
    final r = await http.get(uri).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) {
      throw Exception('Image download failed: HTTP ${r.statusCode}');
    }
    return r.bodyBytes;
  }

  Future<File> _downloadImageToTempFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) throw Exception('Bad image url');

    final r = await http.get(uri).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) {
      throw Exception('Image download failed: HTTP ${r.statusCode}');
    }

    final dir = await getTemporaryDirectory();
    final ext = _guessExtFromUrl(url);
    final file =
        File('${dir.path}/outfit_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await file.writeAsBytes(r.bodyBytes, flush: true);
    return file;
  }

  String _guessExtFromUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.png')) return 'png';
    if (u.contains('.webp')) return 'webp';
    if (u.contains('.jpeg')) return 'jpeg';
    return 'jpg';
  }

  Future<File> _saveInternetImageToAppStorage({
    required String imageUrl,
  }) async {
    final bytes = await _downloadImageBytes(imageUrl);
    final docs = await getApplicationDocumentsDirectory();

    final folder = Directory('${docs.path}/wardrobe');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final ext = _guessExtFromUrl(imageUrl);
    final file =
        File('${folder.path}/wardrobe_${DateTime.now().millisecondsSinceEpoch}.$ext');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onClear() {
    _queryCtrl.clear();
    setState(() {
      _query = "";
      _tabIndex = 1;

      _internetItems.clear();
      _internetTotal = 0;
      _internetStart = 1;
      _internetHasMore = false;
      _internetNextStart = null;
      _errInternet = null;

      _catalogItems.clear();
      _catalogTotal = 0;
      _catalogHasMore = false;
      _catalogPage = 1;
      _errCatalog = null;
    });
  }

  Future<void> _onSearch() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() => _query = q);

    await Future.wait([
      _runCatalogSearch(q),
      _runInternetSearch(q),
    ]);
  }

  // ------------------------
  // INTERNET
  // ------------------------
  Future<void> _runInternetSearch(String q) async {
    setState(() {
      _loadingInternet = true;
      _loadingMoreInternet = false;
      _errInternet = null;

      _internetItems.clear();
      _internetTotal = 0;

      _internetStart = 1;
      _internetHasMore = false;
      _internetNextStart = null;
    });

    try {
      final data =
          await _api.searchInternetImages(q: q, start: 1, num: _internetNum);

      final parsed = _parseInternetResponse(data);

      if (!mounted) return;
      setState(() {
        _internetItems.addAll(parsed.items);
        _internetTotal = parsed.total;
        _internetStart = parsed.start;
        _internetHasMore = parsed.hasMore;
        _internetNextStart = parsed.nextStart;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errInternet = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loadingInternet = false);
    }
  }

  Future<void> _loadMoreInternet() async {
    if (_loadingMoreInternet) return;
    if (_query.isEmpty) return;
    if (!_internetHasMore) return;

    final nextStart = _internetNextStart ?? (_internetStart + _internetNum);
    if (nextStart <= 0) return;

    setState(() => _loadingMoreInternet = true);

    try {
      final data = await _api.searchInternetImages(
        q: _query,
        start: nextStart,
        num: _internetNum,
      );

      final parsed = _parseInternetResponse(data);

      if (!mounted) return;
      setState(() {
        _internetItems.addAll(parsed.items);
        _internetTotal = parsed.total;
        _internetStart = parsed.start;
        _internetHasMore = parsed.hasMore;
        _internetNextStart = parsed.nextStart;
      });

      if (parsed.items.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('search_next_empty')),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errInternet = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loadingMoreInternet = false);
    }
  }

  _InternetParsed _parseInternetResponse(Map<String, dynamic> data) {
    // Поддержка форматов:
    // A) items: [{image_url, page_url, site}]
    // B) items: [{image, thumbnail, link, displayLink}]
    final rawItems = (data['items'] as List?)?.cast<dynamic>() ?? const [];
    final items = <_InternetItem>[];

    for (final e in rawItems) {
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();

      final imageUrl = (m['image_url'] ?? m['image'] ?? m['thumbnail'] ?? '')
          .toString()
          .trim();
      if (imageUrl.isEmpty) continue;

      final pageUrl = (m['page_url'] ?? m['link'] ?? '').toString().trim();
      final site = (m['site'] ?? m['displayLink'] ?? '').toString().trim();

      items.add(
        _InternetItem(
          imageUrl: imageUrl,
          pageUrl: pageUrl.isNotEmpty ? pageUrl : imageUrl,
          site: site,
        ),
      );
    }

    final start = _intOr(data['start'], fallback: 1);
    final num = _intOr(data['num'], fallback: _internetNum);

    int total = _intOr(data['total'], fallback: 0);
    if (total <= 0) total = _internetItems.length + items.length;

    final hasMoreFromApi = data['has_more'];
    final nextStartFromApi = data['next_start'];

    bool hasMore;
    int? nextStart;

    if (hasMoreFromApi is bool) {
      hasMore = hasMoreFromApi;
      nextStart = nextStartFromApi is int ? nextStartFromApi : null;
    } else {
      final currentEnd = (start - 1) + num;
      hasMore = currentEnd < total;
      nextStart = hasMore ? (start + num) : null;
    }

    return _InternetParsed(
      items: items,
      total: total,
      start: start,
      num: num,
      hasMore: hasMore,
      nextStart: nextStart,
    );
  }

  int _intOr(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  // ------------------------
  // PREVIEW + SAVE ACTIONS (Internet)
  // ------------------------

  Future<void> _openInternetPreview(_InternetItem item) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool savingGallery = false;
        bool savingCatalog = false;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> saveGallery() async {
              if (savingGallery) return;

              setStateDialog(() => savingGallery = true);

              try {
                if (kIsWeb || !Platform.isAndroid) {
                  throw Exception('Сохранение в галерею поддержано только на Android.');
                }

                await _initMediaStore();

                // 1) качаем в temp-файл
                final tempFile = await _downloadImageToTempFile(item.imageUrl);

                // 2) сохраняем через MediaStore (в Pictures/Outfit Assistant)
                final mediaStore = MediaStore();
                await mediaStore.saveFile(
                  tempFilePath: tempFile.path,
                  dirType: DirType.photo,
                  dirName: DirName.pictures,
                  relativePath: 'Outfit Assistant',
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('search_saved_gallery'))),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('search_error_save', params: {'error': e.toString()}))),
                );
              } finally {
                if (ctx.mounted) setStateDialog(() => savingGallery = false);
              }
            }

            Future<void> saveToCatalogThings() async {
              if (savingCatalog) return;

              setStateDialog(() => savingCatalog = true);

              try {
                // ВАЖНО: твой CatalogScreen показывает Image.file(File(path)),
                // поэтому мы сохраняем картинку локально в документы приложения.
                if (kIsWeb) {
                  throw Exception('Каталог вещей на Web сейчас не поддержан (нужен локальный файл).');
                }

                final catalog = context.read<CatalogProvider>();

                // простая защита от дублей по URL
                final already = catalog.items.any((x) =>
                    (x.tags.contains(item.imageUrl)) ||
                    (x.imagePath.contains(item.imageUrl)));
                if (already) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('search_exists_catalog'))),
                  );
                  return;
                }

                final localFile = await _saveInternetImageToAppStorage(
                  imageUrl: item.imageUrl,
                );

                final id = catalog.newId();
                final name = (item.site.isNotEmpty)
                    ? 'Internet: ${item.site}'
                    : 'Internet item';

                final clothing = ClothingItem(
                  id: id,
                  name: name,
                  category: 'other',
                  imagePath: localFile.path,
                  tags: [
                    'internet_search',
                    item.site,
                    item.pageUrl,
                    item.imageUrl, // сохраняем исходный URL как тег
                  ].where((e) => e.trim().isNotEmpty).toList(),
                  isNetwork: false, // локальный файл
                  backgroundRemoved: false,
                );

                catalog.addItem(clothing);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('search_saved_catalog'))),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('search_error_general', params: {'error': e.toString()}))), // Reuse general error or generic save error
                );
              } finally {
                if (ctx.mounted) setStateDialog(() => savingCatalog = false);
              }
            }

            final theme = Theme.of(ctx);
            final gold = theme.colorScheme.secondary;

            return Dialog(
              insetPadding: const EdgeInsets.all(14),
              backgroundColor: Colors.white.withOpacity(0.96),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // top bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.90),
                        border: Border(
                          bottom: BorderSide(color: gold.withOpacity(0.18)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                                child: Text(
                                  item.site.isNotEmpty ? item.site : context.tr('search_title'), // 'Preview'? I'll use Search title or generic
                                  // 'Превью' -> 'Preview'. Not in JSON.
                                  // I'll leave 'Preview' hardcoded or use 'search_open' "Open"?
                                  // Let's use 'search_open' ("Open") which is close enough or just hardcode "Preview" if I want.
                                  // Actually let's use 'search_open'
                                  // But context.tr('search_open') is "Open".
                                  // Let's just use "Preview" hardcoded for now or add key.
                                  // I'll stick to hardcoded 'Preview' here as it's minor, or 'search_title' ("Search").
                                  maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Закрыть',
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                          )
                        ],
                      ),
                    ),

                    // image
                    Flexible(
                      child: Container(
                        color: Colors.black.withOpacity(0.02),
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.network(
                            item.imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (c, child, prog) {
                              if (prog == null) return child;
                              return SizedBox(
                                height: 380,
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: prog.expectedTotalBytes != null
                                          ? prog.cumulativeBytesLoaded /
                                              (prog.expectedTotalBytes ?? 1)
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => SizedBox(
                              height: 380,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.broken_image_outlined),
                                    SizedBox(height: 8),
                                    Text('Error'), // "Не удалось загрузить изображение" -> 'my_looks_image_error'
                                    // I have 'my_looks_image_error' -> "Failed to load image"
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // actions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        border: Border(
                          top: BorderSide(color: gold.withOpacity(0.18)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (item.pageUrl.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: gold.withOpacity(0.14)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.link, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.pageUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => _openUrl(item.pageUrl),
                                    child: Text(context.tr('search_open')),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      savingGallery ? null : () => saveGallery(),
                                  icon: savingGallery
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.download),
                                  label: Text(context.tr('search_to_gallery')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: savingCatalog
                                      ? null
                                      : () => saveToCatalogThings(),
                                  icon: savingCatalog
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.bookmark_add_outlined),
                                  label: Text(context.tr('search_to_catalog')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ------------------------
  // CATALOG (Marketplace Products)
  // ------------------------
  Future<void> _runCatalogSearch(String q) async {
    setState(() {
      _loadingCatalog = true;
      _loadingMoreCatalog = false;
      _errCatalog = null;

      _catalogItems.clear();
      _catalogTotal = 0;
      _catalogPage = 1;
      _catalogHasMore = false;
    });

    try {
      final marketplace = context.read<MarketplaceProvider>();
      
      // Search products in marketplace
      final allProducts = marketplace.searchProducts(q);
      
      // Convert to map format for compatibility
      final items = allProducts.map((product) => {
        'id': product.id,
        'name': product.name,
        'price': product.price,
        'image': product.imagePath,
        'category': product.category,
        'store_id': product.storeId,
        'seller_id': product.sellerId,
        'stock': product.stock,
        'product': product, // Store full product object
      }).toList();

      if (!mounted) return;
      setState(() {
        _catalogItems.addAll(items);
        _catalogTotal = items.length;
        _catalogHasMore = false; // All results loaded at once
        _catalogPage = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errCatalog = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loadingCatalog = false);
    }
  }

  Future<void> _loadMoreCatalog() async {
    // Not needed - all results loaded at once
    return;
  }

  Widget _buildMarketplaceResults() {
    if (_loadingCatalog) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errCatalog != null) {
      return Center(
        child: Text(context.tr('search_error_general', params: {'error': _errCatalog!})),
      );
    }

    if (_catalogItems.isEmpty) {
      return Center(
        child: Text(context.tr('search_not_found')),
      );
    }

    return GridView.builder(
      controller: _catalogScroll,
      padding: const EdgeInsets.all(8),
      itemCount: _catalogItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemBuilder: (context, i) {
        final item = _catalogItems[i];
        final product = item['product'] as ClothingItem;
        
        return MarketplaceProductCard(
          product: product,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    final storesLabel =
        context.tr('search_tab_stores', params: {'count': (_catalogTotal > 0 ? _catalogTotal : _catalogItems.length).toString()});
    final internetLabel =
         context.tr('search_tab_internet', params: {'count': (_internetTotal > 0 ? _internetTotal : _internetItems.length).toString()});

    return LuxeScaffold(
      title: context.tr('search_title'),
      child: Column(
        children: [
          _SearchField(
            controller: _queryCtrl,
            onSearch: _onSearch,
            onClear: _onClear,
          ),
          const SizedBox(height: 14),
          _Tabs(
            leftText: storesLabel,
            rightText: internetLabel,
            index: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _query.isEmpty
                ? _EmptyHint(gold: gold)
                : (_tabIndex == 0
                    ? _buildMarketplaceResults()
                    : _InternetView(
                        scroll: _internetScroll,
                        loading: _loadingInternet,
                        loadingMore: _loadingMoreInternet,
                        error: _errInternet,
                        items: _internetItems,
                        hasMore: _internetHasMore,
                        onLoadMore: _loadMoreInternet,
                        onTapItem: _openInternetPreview,
                      )),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: 0.65,
            child: Text(
              'API: $_baseUrl',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------
// Models
// -----------------------------
class _InternetItem {
  final String imageUrl;
  final String pageUrl;
  final String site;

  const _InternetItem({
    required this.imageUrl,
    required this.pageUrl,
    required this.site,
  });
}

class _InternetParsed {
  final List<_InternetItem> items;
  final int total;
  final int start;
  final int num;
  final bool hasMore;
  final int? nextStart;

  const _InternetParsed({
    required this.items,
    required this.total,
    required this.start,
    required this.num,
    required this.hasMore,
    required this.nextStart,
  });
}

// -----------------------------
// UI widgets
// -----------------------------
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function() onSearch;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: context.tr('listing_search_hint'), // Reuse existing search hint
        hintText: context.tr('search_empty_hint_subtitle'), // Reuse explicit hint from empty state if suitable, or just a generic "E.g. ..."
        // Actually listing_search_hint is "Search products...".
        // Let's use it for labelText. 
        // For hintText let's use search_empty_hint_subtitle?
        // Let's keep it simple.
        filled: true,
        fillColor: Colors.white.withOpacity(0.35),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: gold.withOpacity(0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: gold.withOpacity(0.55), width: 1.4),
        ),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.tr('my_looks_clear_all'), // "Refresh"? No "Clear"
              // Reuse "Clear all" -> "Clear" roughly
              icon: const Icon(Icons.clear),
              onPressed: onClear,
            ),
            IconButton(
              tooltip: context.tr('search_title'), // "Search"
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => onSearch(),
            ),
          ],
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
    );
  }
}

class _Tabs extends StatelessWidget {
  final String leftText;
  final String rightText;
  final int index;
  final ValueChanged<int> onChanged;

  const _Tabs({
    required this.leftText,
    required this.rightText,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    Widget pill(String text, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withOpacity(0.55)
                  : Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: gold.withOpacity(selected ? 0.45 : 0.22)),
            ),
            child: Center(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          pill(leftText, index == 0, () => onChanged(0)),
          const SizedBox(width: 8),
          pill(rightText, index == 1, () => onChanged(1)),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final Color gold;
  const _EmptyHint({required this.gold});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.35),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: gold.withOpacity(0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 34, color: theme.colorScheme.primary.withOpacity(0.9)),
            const SizedBox(height: 10),
            Text(
              context.tr('search_empty_hint_title'),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('search_empty_hint_subtitle'),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InternetView extends StatelessWidget {
  final ScrollController scroll;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final List<_InternetItem> items;
  final bool hasMore;
  final VoidCallback onLoadMore;

  final Future<void> Function(_InternetItem item) onTapItem;

  const _InternetView({
    required this.scroll,
    required this.loading,
    required this.loadingMore,
    required this.error,
    required this.items,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(context.tr('search_error_general', params: {'error': error!})));
    if (items.isEmpty) {
      return Center(
          child: Text(context.tr('search_not_found')));
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: scroll,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, i) {
              final it = items[i];
              return _ImageTile(
                imageUrl: it.imageUrl,
                site: it.site,
                onTap: () => onTapItem(it),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (hasMore)
          OutlinedButton(
            onPressed: loadingMore ? null : onLoadMore,
            child: loadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('search_load_more')),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(context.tr('search_no_more')),
          ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String imageUrl;
  final String site;
  final VoidCallback onTap;

  const _ImageTile({
    required this.imageUrl,
    required this.site,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;
    final paper =
        (theme.cardTheme.color ?? theme.colorScheme.surface).withOpacity(0.92);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: gold.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.white.withOpacity(0.18),
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white.withOpacity(0.22),
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              ),
              if (site.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: Colors.black.withOpacity(0.35),
                    child: Text(
                      site,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogView extends StatelessWidget {
  final ScrollController scroll;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final Future<void> Function(String url) onOpen;

  const _CatalogView({
    required this.scroll,
    required this.loading,
    required this.loadingMore,
    required this.error,
    required this.items,
    required this.hasMore,
    required this.onLoadMore,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(context.tr('search_error_general', params: {'error': error!})));
    if (items.isEmpty) return Center(child: Text(context.tr('search_catalog_empty')));

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: scroll,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final it = items[i];
              final title = (it['title'] ?? it['name'] ?? 'Товар').toString();
              final brand = (it['brand'] ?? '').toString();
              final price = (it['price'] ?? '').toString();
              final currency = (it['currency'] ?? '').toString();
              final imageUrl = (it['image_url'] ?? '').toString();
              final productUrl = (it['product_url'] ?? '').toString();

              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: productUrl.isNotEmpty ? () => onOpen(productUrl) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: (theme.cardTheme.color ?? theme.colorScheme.surface)
                        .withOpacity(0.92),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: gold.withOpacity(0.22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: imageUrl.isEmpty
                              ? Container(
                                  color: Colors.white.withOpacity(0.25),
                                  child: const Center(
                                      child: Icon(Icons.checkroom)),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white.withOpacity(0.25),
                                    child: const Center(
                                        child: Icon(Icons.image_not_supported)),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (brand.isNotEmpty) brand,
                                if (price.isNotEmpty) '$price $currency'
                              ].join(' • '),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.open_in_new,
                          color: theme.colorScheme.primary.withOpacity(0.85)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (hasMore)
          OutlinedButton(
            onPressed: loadingMore ? null : onLoadMore,
            child: loadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('search_load_more')),
          )
        else
           Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(context.tr('search_no_more')),
          ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// -----------------------------
// API client
// baseUrl = http://IP:8000 (БЕЗ /api/v1)
// -----------------------------
class _SearchApi {
  final String baseUrl; // http://IP:8000
  const _SearchApi({required this.baseUrl});

  Future<Map<String, dynamic>> searchInternetImages({
    required String q,
    required int start,
    required int num,
  }) async {
    final uri = Uri.parse('$baseUrl/search/images').replace(queryParameters: {
      'q': q,
      'start': start.toString(),
      'num': num.toString(),
    });

    final r = await http.get(uri).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return (jsonDecode(r.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> searchCatalog({
    required String q,
    required int page,
    required int pageSize,
  }) async {
    final uri = Uri.parse('$baseUrl/search/catalog').replace(queryParameters: {
      'q': q,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });

    final r = await http.get(uri).timeout(const Duration(seconds: 25));

    if (r.statusCode == 404) {
      return {
        'source': 'catalog',
        'total': 0,
        'items': <dynamic>[],
        'has_more': false,
      };
    }

    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return (jsonDecode(r.body) as Map).cast<String, dynamic>();
  }
}
