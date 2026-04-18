// lib/screens/magasin/list_magasin_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/magasin.dart';
import '../../services/magasin_service.dart';
import '../../services/annonce_service.dart';

class ListMagasinScreen extends StatefulWidget {
  final String? initialVille;
  final String? initialCategorie;

  const ListMagasinScreen({
    super.key,
    this.initialVille,
    this.initialCategorie,
  });

  @override
  State<ListMagasinScreen> createState() => _ListMagasinScreenState();
}

class _ListMagasinScreenState extends State<ListMagasinScreen> {
  final _service = MagasinService();
  final _searchCtrl = TextEditingController();

  List<Magasin> _magasins = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _cities = [];
  List<Marche> _marches = [];
  List<Marche> _filteredMarches = [];

  bool _loading = true;
  String? _error;

  String? _selectedVille;
  String? _selectedCategorie;
  String? _selectedMarche;
  bool _verifiedOnly = false;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedVille = widget.initialVille;
    _selectedCategorie = widget.initialCategorie;
    _loadReferenceData();
    _loadMagasins();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    try {
      final results = await Future.wait([
        AnnonceService().getCategories(),
        AnnonceService().getCities(),
        _service.getMarches(),
      ]);
      if (mounted) {
        setState(() {
          _categories = results[0] as List<Map<String, dynamic>>;
          _cities = results[1] as List<Map<String, dynamic>>;
          _marches = results[2] as List<Marche>;
          _filterMarches();
        });
      }
    } catch (_) {}
  }

  void _filterMarches() {
    _filteredMarches = _selectedVille != null && _selectedVille!.isNotEmpty
        ? _marches.where((m) => m.villeCode == _selectedVille).toList()
        : _marches;
  }

  Future<void> _loadMagasins() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getMagasins(
        ville: _selectedVille,
        categorie: _selectedCategorie,
        marche: _selectedMarche,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        verifiedOnly: _verifiedOnly,
      );
      if (mounted) setState(() => _magasins = list);
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = value);
      _loadMagasins();
    });
  }

  void _showFilters() {
    String? tmpVille = _selectedVille;
    String? tmpCategorie = _selectedCategorie;
    String? tmpMarche = _selectedMarche;
    bool tmpVerified = _verifiedOnly;
    List<Marche> tmpFiltered = List.from(_filteredMarches);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, sc) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
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
                              _selectedVille = null;
                              _selectedCategorie = null;
                              _selectedMarche = null;
                              _verifiedOnly = false;
                              _filterMarches();
                            });
                            Navigator.pop(ctx);
                            _loadMagasins();
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
                  Expanded(
                    child: ListView(
                      controller: sc,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Catégorie
                        const _FilterTitle('Catégorie'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChip(
                              label: 'Toutes',
                              selected: tmpCategorie == null,
                              onTap: () => setLocal(() => tmpCategorie = null),
                            ),
                            ..._categories.map(
                              (c) => _FilterChip(
                                label: c['label'] ?? '',
                                selected: tmpCategorie == c['value'],
                                onTap: () => setLocal(
                                  () => tmpCategorie = c['value'] as String?,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Ville
                        const _FilterTitle('Ville'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChip(
                              label: 'Toutes',
                              selected: tmpVille == null,
                              onTap: () => setLocal(() {
                                tmpVille = null;
                                tmpMarche = null;
                                tmpFiltered = _marches;
                              }),
                            ),
                            ..._cities
                                .take(12)
                                .map(
                                  (c) => _FilterChip(
                                    label: c['label'] ?? '',
                                    selected: tmpVille == c['value'],
                                    onTap: () => setLocal(() {
                                      tmpVille = c['value'] as String?;
                                      tmpMarche = null;
                                      tmpFiltered = _marches
                                          .where((m) => m.villeCode == tmpVille)
                                          .toList();
                                    }),
                                  ),
                                ),
                          ],
                        ),
                        if (tmpVille != null && tmpFiltered.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const _FilterTitle('Marché'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterChip(
                                label: 'Tous',
                                selected: tmpMarche == null,
                                onTap: () => setLocal(() => tmpMarche = null),
                              ),
                              ...tmpFiltered.map(
                                (m) => _FilterChip(
                                  label: m.label,
                                  selected: tmpMarche == m.value,
                                  onTap: () =>
                                      setLocal(() => tmpMarche = m.value),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Vérifiés
                        GestureDetector(
                          onTap: () =>
                              setLocal(() => tmpVerified = !tmpVerified),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: tmpVerified
                                  ? AppTheme.successGreenLight
                                  : AppTheme.gray100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tmpVerified
                                    ? AppTheme.successGreen
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  color: tmpVerified
                                      ? AppTheme.successGreen
                                      : AppTheme.gray500,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Magasins vérifiés uniquement',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: tmpVerified
                                        ? AppTheme.successGreen
                                        : AppTheme.gray700,
                                  ),
                                ),
                                const Spacer(),
                                if (tmpVerified)
                                  Icon(
                                    Icons.check_circle,
                                    color: AppTheme.successGreen,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
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
                            _selectedVille = tmpVille;
                            _selectedCategorie = tmpCategorie;
                            _selectedMarche = tmpMarche;
                            _verifiedOnly = tmpVerified;
                            _filterMarches();
                          });
                          Navigator.pop(ctx);
                          _loadMagasins();
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
          );
        },
      ),
    );
  }

  int get _activeFilters => [
    _selectedVille,
    _selectedCategorie,
    _selectedMarche,
    _verifiedOnly ? true : null,
  ].where((f) => f != null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFF22C55E)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/accueil'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Magasins & Boutiques',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Découvrez les boutiques près de chez vous',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearch,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un magasin...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _onSearch('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _showFilters,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _activeFilters > 0
                            ? Colors.white
                            : Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: _activeFilters > 0
                                ? AppTheme.primaryOrange
                                : Colors.white,
                            size: 22,
                          ),
                          if (_activeFilters > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_activeFilters',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }
    if (_error != null && _magasins.isEmpty) {
      return _buildError();
    }
    if (_magasins.isEmpty) {
      return _buildEmpty();
    }
    return RefreshIndicator(
      onRefresh: _loadMagasins,
      color: AppTheme.primaryOrange,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_magasins.length} magasin(s) trouvé(s)',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _magasins.length,
            itemBuilder: (_, i) => _MagasinCard(
              magasin: _magasins[i],
              onTap: () => context.push('/magasins/${_magasins[i].id}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadMagasins,
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

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏪', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'Aucun magasin trouvé',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Essayez de modifier vos critères de recherche.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.gray500),
          ),
          if (_activeFilters > 0) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedVille = null;
                  _selectedCategorie = null;
                  _selectedMarche = null;
                  _verifiedOnly = false;
                });
                _loadMagasins();
              },
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

// ─── Carte magasin ────────────────────────────────────────────────────────────

class _MagasinCard extends StatelessWidget {
  final Magasin magasin;
  final VoidCallback onTap;

  const _MagasinCard({required this.magasin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Bannière gradient + logo
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 70,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFF22C55E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
                if (magasin.isVerified)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            color: Color(0xFF22C55E),
                            size: 10,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Vérifié',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  bottom: -20,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: magasin.logoAbsoluteUrl != null
                          ? Image.network(
                              magasin.logoAbsoluteUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initials(magasin),
                            )
                          : _initials(magasin),
                    ),
                  ),
                ),
              ],
            ),
            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 26, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      magasin.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.gray900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      magasin.categorieDisplay,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: AppTheme.gray400,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            magasin.villeDisplay,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.gray500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${magasin.nbAnnonces} annonce(s)',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.gray500,
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              'Voir',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 8,
                              color: AppTheme.primaryOrange,
                            ),
                          ],
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

  Widget _initials(Magasin m) => Container(
    color: AppTheme.primaryOrangeLight,
    child: Center(
      child: Text(
        m.initials,
        style: const TextStyle(
          color: AppTheme.primaryOrange,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    ),
  );
}

// ─── Helpers UI ───────────────────────────────────────────────────────────────

class _FilterTitle extends StatelessWidget {
  final String text;
  const _FilterTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
  );
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryOrange : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
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
