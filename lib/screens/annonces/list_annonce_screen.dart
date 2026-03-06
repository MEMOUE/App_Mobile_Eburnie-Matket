// lib/screens/annonces/list_annonce_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/annonce.dart';
import '../../services/annonce_service.dart';
import '../../config/app_theme.dart';
import 'detail_annonce_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ListAnnonceScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialCity;
  final String? initialSearch;
  final VoidCallback? onGoToLogin;

  const ListAnnonceScreen({
    super.key,
    this.initialCategory,
    this.initialCity,
    this.initialSearch,
    this.onGoToLogin,
  });

  @override
  State<ListAnnonceScreen> createState() => _ListAnnonceScreenState();
}

class _ListAnnonceScreenState extends State<ListAnnonceScreen> {
  // ─── État ─────────────────────────────────────────────────────────────────

  final List<Ad> _ads = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;
  int _totalCount = 0;

  // Filtres
  String? _selectedCategory;
  String? _selectedCity;
  String _searchQuery = '';
  String _ordering = '-created_at';
  double? _priceMin;
  double? _priceMax;

  // Catégories & villes pour les filtres
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _cities = [];

  // Contrôleurs
  late TextEditingController _searchCtrl;
  late ScrollController _scrollCtrl;
  Timer? _searchDebounce;

  // Panel filtre ouvert
  bool _filterPanelOpen = false;

  // ─── Constantes ───────────────────────────────────────────────────────────

  static const _categoryIcons = {
    'vehicules': '🚗',
    'emploi': '💼',
    'immobilier': '🏠',
    'electronique': '📱',
    'mode': '👗',
    'maison': '🏡',
    'loisirs': '⚽',
    'services': '🎓',
    'animaux': '🐾',
    'autres': '🎨',
  };

  static const _orderingOptions = [
    {'label': 'Plus récentes', 'value': '-created_at'},
    {'label': 'Plus anciennes', 'value': 'created_at'},
    {'label': 'Prix croissant', 'value': 'price'},
    {'label': 'Prix décroissant', 'value': '-price'},
    {'label': 'Plus vues', 'value': '-views_count'},
  ];

  // ─── Cycle de vie ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedCity = widget.initialCity;
    _searchQuery = widget.initialSearch ?? '';
    _searchCtrl = TextEditingController(text: _searchQuery);
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScroll);
    _loadFiltersData();
    _loadAds(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ─── Chargement ───────────────────────────────────────────────────────────

  Future<void> _loadFiltersData() async {
    try {
      final cats = await AnnonceService().getCategories();
      final cities = await AnnonceService().getCities();
      if (mounted) {
        setState(() {
          _categories = cats;
          _cities = cities;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAds({bool reset = false}) async {
    if (_loading || (_loadingMore && !reset)) return;

    if (reset) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _currentPage = 1;
        _hasMore = true;
        _ads.clear();
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final response = await AnnonceService().getAds(
        category: _selectedCategory,
        city: _selectedCity,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        priceMin: _priceMin,
        priceMax: _priceMax,
        ordering: _ordering,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          _ads.addAll(response.results);
          _totalCount = response.count;
          _hasMore = response.hasMore;
          _currentPage++;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loadingMore) {
      _loadAds();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 600), () {
      setState(() => _searchQuery = value);
      _loadAds(reset: true);
    });
  }

  void _applyFilters() {
    Navigator.of(context).pop();
    _loadAds(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedCity = null;
      _priceMin = null;
      _priceMax = null;
      _ordering = '-created_at';
    });
    Navigator.of(context).pop();
    _loadAds(reset: true);
  }

  // ─── Contact ──────────────────────────────────────────────────────────────

  Future<void> _launchWhatsApp(Ad ad) async {
    final number = ad.contactWhatsApp;
    if (number == null) return;
    final phone = number.startsWith('+') || number.startsWith('00')
        ? number.replaceAll(RegExp(r'[^0-9]'), '')
        : '225${number.replaceAll(RegExp(r'[^0-9]'), '')}';
    final msg = Uri.encodeComponent(
      "Bonjour, je suis intéressé par votre annonce \"${ad.title}\" à ${ad.formattedPrice}",
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$msg');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchCall(Ad ad) async {
    final number = ad.contactPhone;
    if (number == null) return;
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ─── Filtre Bottom Sheet ───────────────────────────────────────────────────

  void _showFilterSheet() {
    // Variables temporaires
    String? tmpCategory = _selectedCategory;
    String? tmpCity = _selectedCity;
    String tmpOrdering = _ordering;
    final minCtrl = TextEditingController(
      text: _priceMin != null ? _priceMin!.toInt().toString() : '',
    );
    final maxCtrl = TextEditingController(
      text: _priceMax != null ? _priceMax!.toInt().toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, sc) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtres',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = null;
                            _selectedCity = null;
                            _priceMin = null;
                            _priceMax = null;
                            _ordering = '-created_at';
                          });
                          Navigator.pop(ctx);
                          _loadAds(reset: true);
                        },
                        child: const Text(
                          'Réinitialiser',
                          style: TextStyle(color: AppTheme.primaryOrange),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Contenu
                Expanded(
                  child: ListView(
                    controller: sc,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Tri
                      _FilterSection(
                        title: 'Trier par',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _orderingOptions
                              .map(
                                (opt) => _FilterChip(
                                  label: opt['label']!,
                                  selected: tmpOrdering == opt['value'],
                                  onTap: () => setLocal(
                                    () => tmpOrdering = opt['value']!,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Catégorie
                      _FilterSection(
                        title: 'Catégorie',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChip(
                              label: 'Toutes',
                              selected: tmpCategory == null,
                              onTap: () => setLocal(() => tmpCategory = null),
                            ),
                            ..._buildCategoryChips(
                              tmpCategory,
                              (v) => setLocal(() => tmpCategory = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Ville
                      if (_cities.isNotEmpty) ...[
                        _FilterSection(
                          title: 'Ville',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterChip(
                                label: 'Toutes',
                                selected: tmpCity == null,
                                onTap: () => setLocal(() => tmpCity = null),
                              ),
                              ..._cities
                                  .take(10)
                                  .map(
                                    (c) => _FilterChip(
                                      label: c['display'] ?? c['name'] ?? '',
                                      selected: tmpCity == c['value'],
                                      onTap: () =>
                                          setLocal(() => tmpCity = c['value']),
                                    ),
                                  )
                                  .toList(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Prix
                      _FilterSection(
                        title: 'Fourchette de prix (FCFA)',
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Min',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '—',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: maxCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Max',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                // Bouton Appliquer
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    MediaQuery.of(ctx).viewInsets.bottom + 20,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = tmpCategory;
                          _selectedCity = tmpCity;
                          _ordering = tmpOrdering;
                          _priceMin = minCtrl.text.isNotEmpty
                              ? double.tryParse(minCtrl.text)
                              : null;
                          _priceMax = maxCtrl.text.isNotEmpty
                              ? double.tryParse(maxCtrl.text)
                              : null;
                        });
                        Navigator.pop(ctx);
                        _loadAds(reset: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Appliquer les filtres',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryChips(
    String? selected,
    void Function(String?) onSelect,
  ) {
    const staticCats = [
      {'label': 'Véhicules', 'value': 'vehicules'},
      {'label': 'Emploi', 'value': 'emploi'},
      {'label': 'Immobilier', 'value': 'immobilier'},
      {'label': 'Électronique', 'value': 'electronique'},
      {'label': 'Mode', 'value': 'mode'},
      {'label': 'Maison', 'value': 'maison'},
      {'label': 'Loisirs', 'value': 'loisirs'},
      {'label': 'Services', 'value': 'services'},
      {'label': 'Animaux', 'value': 'animaux'},
      {'label': 'Autres', 'value': 'autres'},
    ];

    final source = _categories.isNotEmpty ? _categories : staticCats;

    return source
        .map(
          (c) => _FilterChip(
            label: c['label'] ?? c['display'] ?? '',
            selected: selected == c['value'],
            onTap: () => onSelect(c['value'] as String?),
          ),
        )
        .toList();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activeFilters = [
      _selectedCategory,
      _selectedCity,
      _priceMin,
      _priceMax,
    ].where((f) => f != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          _buildTopBar(activeFilters),
          _buildActiveFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTopBar(int activeFilters) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          // Champ de recherche
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Rechercher une annonce...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bouton filtre
          GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: activeFilters > 0
                    ? AppTheme.primaryOrange
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: activeFilters > 0 ? Colors.white : Colors.grey[700],
                    size: 22,
                  ),
                  if (activeFilters > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$activeFilters',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];

    if (_selectedCategory != null) {
      chips.add(
        _ActiveChip(
          label: _selectedCategory!,
          onRemove: () {
            setState(() => _selectedCategory = null);
            _loadAds(reset: true);
          },
        ),
      );
    }
    if (_selectedCity != null) {
      chips.add(
        _ActiveChip(
          label: _selectedCity!,
          onRemove: () {
            setState(() => _selectedCity = null);
            _loadAds(reset: true);
          },
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = null;
                _selectedCity = null;
                _priceMin = null;
                _priceMax = null;
              });
              _loadAds(reset: true);
            },
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text(
              'Tout effacer',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryOrange),
            SizedBox(height: 16),
            Text(
              'Chargement des annonces...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _ads.isEmpty) {
      return _ErrorWidget(
        message: _errorMessage!,
        onRetry: () => _loadAds(reset: true),
      );
    }

    if (_ads.isEmpty) {
      return _EmptyWidget(
        hasFilters:
            _selectedCategory != null ||
            _selectedCity != null ||
            _searchQuery.isNotEmpty,
        onClearFilters: () {
          setState(() {
            _selectedCategory = null;
            _selectedCity = null;
            _searchQuery = '';
            _searchCtrl.clear();
          });
          _loadAds(reset: true);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadAds(reset: true),
      color: AppTheme.primaryOrange,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          // Compteur
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '$_totalCount annonce${_totalCount > 1 ? 's' : ''} trouvée${_totalCount > 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Grille
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _AdCard(
                  ad: _ads[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailAnnonceScreen(
                        adId: _ads[i].id,
                        onGoToLogin: widget.onGoToLogin,
                      ),
                    ),
                  ),
                  onWhatsApp: () => _launchWhatsApp(_ads[i]),
                  onCall: () => _launchCall(_ads[i]),
                ),
                childCount: _ads.length,
              ),
            ),
          ),
          // Loader bas de page
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          if (!_hasMore && _ads.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Toutes les annonces ont été chargées',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Widgets internes ─────────────────────────────────────────────────────────

class _AdCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap;
  final VoidCallback onWhatsApp;
  final VoidCallback onCall;

  const _AdCard({
    required this.ad,
    required this.onTap,
    required this.onWhatsApp,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: SizedBox(
                    height: 130,
                    width: double.infinity,
                    child:
                        ad.mainImageUrl != null && ad.mainImageUrl!.isNotEmpty
                        ? Image.network(
                            ad.mainImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _ImagePlaceholder(category: ad.categoryDisplay),
                          )
                        : _ImagePlaceholder(category: ad.categoryDisplay),
                  ),
                ),
                // Badges
                Positioned(
                  top: 6,
                  left: 6,
                  child: Row(
                    children: [
                      if (ad.isFeatured)
                        _Badge(label: 'VEDETTE', color: AppTheme.primaryOrange),
                      if (ad.isUrgent)
                        _Badge(label: 'URGENT', color: Colors.red),
                    ],
                  ),
                ),
              ],
            ),
            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ad.formattedPrice,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    if (ad.isNegotiable)
                      Text(
                        'Négociable',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    const Spacer(),
                    // Ville
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            ad.cityDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Boutons contact
                    Row(
                      children: [
                        _ContactBtn(
                          icon: Icons.chat,
                          color: const Color(0xFF25D366),
                          onTap: onWhatsApp,
                          tooltip: 'WhatsApp',
                        ),
                        const SizedBox(width: 6),
                        _ContactBtn(
                          icon: Icons.phone,
                          color: Colors.blueAccent,
                          onTap: onCall,
                          tooltip: 'Appeler',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String category;
  const _ImagePlaceholder({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryOrange.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 36,
              color: AppTheme.primaryOrange.withOpacity(0.4),
            ),
            const SizedBox(height: 4),
            Text(
              category,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.primaryOrange.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ContactBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _FilterSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryOrange : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryOrange : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.primaryOrange),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppTheme.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;
  const _EmptyWidget({required this.hasFilters, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasFilters ? '🔍' : '📭',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'Aucune annonce ne correspond à vos critères'
                  : 'Aucune annonce disponible',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: onClearFilters,
                child: const Text(
                  'Effacer les filtres',
                  style: TextStyle(color: AppTheme.primaryOrange),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
