// lib/screens/magasin/list_marche_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/magasin.dart';
import '../../services/magasin_service.dart';

const _marcheColors = [
  [Color(0xFFF97316), Color(0xFFEA580C)],
  [Color(0xFF22C55E), Color(0xFF15803D)],
  [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  [Color(0xFFEC4899), Color(0xFFBE185D)],
  [Color(0xFF14B8A6), Color(0xFF0F766E)],
  [Color(0xFFF59E0B), Color(0xFFB45309)],
  [Color(0xFF06B6D4), Color(0xFF0E7490)],
];

class ListMarcheScreen extends StatefulWidget {
  const ListMarcheScreen({super.key});

  @override
  State<ListMarcheScreen> createState() => _ListMarcheScreenState();
}

class _ListMarcheScreenState extends State<ListMarcheScreen> {
  List<MarcheGroup> _allGroups = [];
  List<MarcheGroup> _filtered = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _selectedVille; // null = toutes les villes

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Chargement ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // On utilise getMarches() (liste plate) pour avoir TOUTES les villes,
      // y compris celles avec < 2 marchés.
      final marches = await MagasinService().getMarches();
      if (mounted) {
        // Groupement côté client
        final Map<String, MarcheGroup> grouped = {};
        for (final m in marches) {
          if (!grouped.containsKey(m.villeCode)) {
            grouped[m.villeCode] = MarcheGroup(
              ville: m.villeCode,
              villeLabel: m.villeLabel.isNotEmpty ? m.villeLabel : m.villeCode,
              marches: [],
            );
          }
          grouped[m.villeCode]!.marches.add(m);
        }
        final groups = grouped.values.toList()
          ..sort((a, b) => a.villeLabel.compareTo(b.villeLabel));
        setState(() {
          _allGroups = groups;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  void _applyFilters() {
    final q = _search.toLowerCase().trim();
    _filtered = _allGroups
        .where((g) {
          // Filtre ville
          if (_selectedVille != null && g.ville != _selectedVille) return false;
          // Filtre recherche : sur nom de ville OU nom de marché
          if (q.isEmpty) return true;
          if (g.villeLabel.toLowerCase().contains(q)) return true;
          return g.marches.any((m) => m.label.toLowerCase().contains(q));
        })
        .map((g) {
          // Si recherche active, filtrer aussi les marchés dans le groupe
          if (q.isEmpty || g.villeLabel.toLowerCase().contains(q)) return g;
          return MarcheGroup(
            ville: g.ville,
            villeLabel: g.villeLabel,
            marches: g.marches
                .where((m) => m.label.toLowerCase().contains(q))
                .toList(),
          );
        })
        .where((g) => g.marches.isNotEmpty)
        .toList();
    setState(() {});
  }

  int get _totalMarches => _filtered.fold(0, (s, g) => s + g.marches.length);

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          _buildHeader(),
          if (!_loading && _error == null) _buildFiltersBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF14B8A6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top row
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tous les Marchés',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _loading
                              ? 'Chargement...'
                              : '${_allGroups.length} ville(s) · $_totalMarches marché(s)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bouton voir les magasins
                  GestureDetector(
                    onTap: () => context.go('/magasins'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Magasins',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Barre de recherche
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) {
                    _search = v;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher une ville ou un marché...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
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
                              _search = '';
                              _applyFilters();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Chips de filtre par ville ─────────────────────────────────────────────

  Widget _buildFiltersBar() {
    final villes = _allGroups.map((g) => g).toList();
    if (villes.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _VilleChip(
              label: 'Toutes',
              count: _allGroups.fold(0, (s, g) => s + g.marches.length),
              selected: _selectedVille == null,
              color: const Color(0xFF22C55E),
              onTap: () {
                setState(() => _selectedVille = null);
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            ...villes.map((g) {
              final idx = villes.indexOf(g);
              final colors = _marcheColors[idx % _marcheColors.length];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _VilleChip(
                  label: g.villeLabel,
                  count: g.marches.length,
                  selected: _selectedVille == g.ville,
                  color: colors[0],
                  onTap: () {
                    setState(
                      () => _selectedVille = _selectedVille == g.ville
                          ? null
                          : g.ville,
                    );
                    _applyFilters();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Corps ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF22C55E)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 56,
                color: AppTheme.gray400,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.gray600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏪', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'Aucun marché trouvé',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                _search = '';
                _selectedVille = null;
                _applyFilters();
              },
              child: const Text(
                'Effacer les filtres',
                style: TextStyle(color: Color(0xFF22C55E)),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _filtered.length,
        itemBuilder: (_, i) {
          final g = _filtered[i];
          final colorIdx = _allGroups.indexWhere((x) => x.ville == g.ville);
          return _VilleSection(
            group: g,
            colorPair: _marcheColors[colorIdx % _marcheColors.length],
            onMarcheTap: (marche) =>
                context.go('/magasins?marche=${marche.value}'),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section d'une ville avec ses marchés
// ══════════════════════════════════════════════════════════════════════════════

class _VilleSection extends StatefulWidget {
  final MarcheGroup group;
  final List<Color> colorPair;
  final Function(Marche) onMarcheTap;
  const _VilleSection({
    required this.group,
    required this.colorPair,
    required this.onMarcheTap,
  });

  @override
  State<_VilleSection> createState() => _VilleSectionState();
}

class _VilleSectionState extends State<_VilleSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── En-tête ville ──
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.colorPair,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: _expanded
                    ? const BorderRadius.vertical(top: Radius.circular(18))
                    : BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_city_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.villeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${widget.group.marches.length} marché(s)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Liste des marchés ──
          AnimatedCrossFade(
            firstChild: Column(
              children: List.generate(widget.group.marches.length, (i) {
                final m = widget.group.marches[i];
                final isLast = i == widget.group.marches.length - 1;
                return _MarcheRow(
                  marche: m,
                  color: widget.colorPair[0],
                  isLast: isLast,
                  onTap: () => widget.onMarcheTap(m),
                );
              }),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

// ── Ligne d'un marché ──────────────────────────────────────────────────────────

class _MarcheRow extends StatelessWidget {
  final Marche marche;
  final Color color;
  final bool isLast;
  final VoidCallback onTap;
  const _MarcheRow({
    required this.marche,
    required this.color,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(18))
              : null,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  // Pastille colorée
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Icon(
                      Icons.store_mall_directory_outlined,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      marche.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray900,
                      ),
                    ),
                  ),
                  // CTA voir les magasins
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Voir',
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: color,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(height: 1, indent: 66, color: AppTheme.gray200),
          ],
        ),
      ),
    );
  }
}

// ── Chip filtre ville ──────────────────────────────────────────────────────────

class _VilleChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _VilleChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.gray700,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.25)
                    : AppTheme.gray200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppTheme.gray500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
