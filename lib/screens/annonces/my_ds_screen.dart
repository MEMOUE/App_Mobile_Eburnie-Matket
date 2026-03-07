// lib/screens/annonces/my_ads_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../models/annonce.dart';
import '../../services/annonce_service.dart';

class MyAdsScreen extends StatefulWidget {
  const MyAdsScreen({super.key});

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen>
    with SingleTickerProviderStateMixin {
  final _service = AnnonceService();
  late final TabController _tabCtrl;

  List<Ad> _allAds = [];
  bool _loading = true;
  String? _error;

  static const _tabs = ['Toutes', 'Actives', 'En attente', 'Expirées'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _loadAds();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ─── Chargement ───────────────────────────────────────────────────────────

  Future<void> _loadAds() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ads = await _service.getMyAds();
      setState(() => _allAds = ads);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Filtrage par onglet ──────────────────────────────────────────────────

  List<Ad> _filtered(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _allAds.where((a) => a.status == 'active').toList();
      case 2:
        return _allAds.where((a) => a.status == 'pending').toList();
      case 3:
        return _allAds.where((a) => a.status == 'expired').toList();
      default:
        return _allAds;
    }
  }

  // ─── Suppression ─────────────────────────────────────────────────────────

  Future<void> _confirmDelete(Ad ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Supprimer l\'annonce',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${ad.title}" ? Cette action est irréversible.',
          style: const TextStyle(color: AppTheme.gray600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppTheme.gray600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteAd(ad.id);
      setState(() => _allAds.removeWhere((a) => a.id == ad.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Annonce supprimée'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mes annonces'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/accueil'),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primaryOrange,
          labelColor: AppTheme.primaryOrange,
          unselectedLabelColor: AppTheme.gray500,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: List.generate(_tabs.length, (i) {
            final count = i == 0 ? _allAds.length : _filtered(i).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_tabs[i]),
                  if (!_loading && count > 0) ...[
                    const SizedBox(width: 6),
                    _TabBadge(count: count, tabIndex: i),
                  ],
                ],
              ),
            );
          }),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : _error != null
          ? _buildError()
          : TabBarView(
              controller: _tabCtrl,
              children: List.generate(
                _tabs.length,
                (i) => RefreshIndicator(
                  color: AppTheme.primaryOrange,
                  onRefresh: _loadAds,
                  child: _buildTabContent(i),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-ad'),
        backgroundColor: AppTheme.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Publier',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ─── Contenu d'un onglet ──────────────────────────────────────────────────

  Widget _buildTabContent(int tabIndex) {
    final ads = _filtered(tabIndex);
    if (ads.isEmpty) return _buildEmpty(tabIndex);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: ads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _AdCard(
        ad: ads[i],
        onEdit: () => context.go('/edit-ad/${ads[i].id}'),
        onDelete: () => _confirmDelete(ads[i]),
      ),
    );
  }

  // ─── État vide ────────────────────────────────────────────────────────────

  Widget _buildEmpty(int tabIndex) {
    final isAllTab = tabIndex == 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAllTab ? Icons.storefront_outlined : Icons.inbox_outlined,
                size: 44,
                color: AppTheme.primaryOrange,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isAllTab
                  ? 'Aucune annonce pour l\'instant'
                  : 'Aucune annonce dans cette catégorie',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAllTab
                  ? 'Publiez votre première annonce\net commencez à vendre !'
                  : 'Vos annonces ${_tabs[tabIndex].toLowerCase()}\napparaîtront ici.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.gray500),
            ),
            if (isAllTab) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.go('/create-ad'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Publier une annonce',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Vue erreur ───────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              style: const TextStyle(color: AppTheme.gray600, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAds,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Badge compteur sur onglet ─────────────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  final int count;
  final int tabIndex;
  const _TabBadge({required this.count, required this.tabIndex});

  Color get _color {
    switch (tabIndex) {
      case 1:
        return AppTheme.successGreen;
      case 2:
        return Colors.amber;
      case 3:
        return AppTheme.errorRed;
      default:
        return AppTheme.primaryOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _color,
        ),
      ),
    );
  }
}

// ─── Carte annonce ─────────────────────────────────────────────────────────────

class _AdCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AdCard({
    required this.ad,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ────────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: SizedBox(
              width: 100,
              height: 110,
              child: ad.mainImageUrl != null
                  ? Image.network(
                      ad.mainImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          // ── Contenu ───────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusBadge(status: ad.status),
                      if (ad.isUrgent) ...[
                        const SizedBox(width: 6),
                        _UrgentBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ad.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppTheme.gray400,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _cityLabel(ad.city),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.label_outline,
                        size: 13,
                        color: AppTheme.gray400,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _categoryLabel(ad.category),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${fmt.format(ad.price)} FCFA',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.edit_outlined,
                          label: 'Modifier',
                          color: AppTheme.primaryOrange,
                          onTap: onEdit,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.delete_outline,
                          label: 'Supprimer',
                          color: AppTheme.errorRed,
                          onTap: onDelete,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppTheme.gray100,
    child: const Center(
      child: Icon(Icons.image_outlined, color: AppTheme.gray400, size: 32),
    ),
  );

  String _cityLabel(String? city) {
    const map = {
      'abidjan': 'Abidjan',
      'bouake': 'Bouaké',
      'daloa': 'Daloa',
      'korhogo': 'Korhogo',
      'yamoussoukro': 'Yamoussoukro',
      'man': 'Man',
      'gagnoa': 'Gagnoa',
      'san_pedro': 'San-Pédro',
      'divo': 'Divo',
      'abengourou': 'Abengourou',
    };
    return map[city] ?? city ?? '';
  }

  String _categoryLabel(String? cat) {
    const map = {
      'vehicules': 'Véhicules',
      'emploi_stages': 'Emploi',
      'immobilier': 'Immobilier',
      'electronique': 'Électronique',
      'maison_jardin': 'Maison',
      'mode_beaute': 'Mode',
      'sport_loisirs': 'Sport',
      'services': 'Services',
      'agroalimentaire': 'Agro',
      'animaux': 'Animaux',
      'autres': 'Autres',
    };
    return map[cat] ?? cat ?? '';
  }
}

// ─── Badge statut ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String? status;
  const _StatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;
    switch (status) {
      case 'active':
        bg = AppTheme.successGreen.withOpacity(0.12);
        fg = AppTheme.successGreen;
        label = 'Active';
        icon = Icons.check_circle_outline;
        break;
      case 'pending':
        bg = Colors.amber.withOpacity(0.12);
        fg = Colors.amber.shade700;
        label = 'En attente';
        icon = Icons.schedule_outlined;
        break;
      case 'expired':
        bg = AppTheme.errorRed.withOpacity(0.10);
        fg = AppTheme.errorRed;
        label = 'Expirée';
        icon = Icons.timer_off_outlined;
        break;
      default:
        bg = AppTheme.gray100;
        fg = AppTheme.gray500;
        label = status ?? 'Inconnu';
        icon = Icons.help_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badge urgent ─────────────────────────────────────────────────────────────

class _UrgentBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 11, color: AppTheme.errorRed),
          const SizedBox(width: 3),
          Text(
            'Urgent',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.errorRed,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bouton d'action (Modifier / Supprimer) ───────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
