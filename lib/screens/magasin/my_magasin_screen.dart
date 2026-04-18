// lib/screens/magasin/my_magasin_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/magasin.dart';
import '../../services/magasin_service.dart';

class MyMagasinScreen extends StatefulWidget {
  const MyMagasinScreen({super.key});

  @override
  State<MyMagasinScreen> createState() => _MyMagasinScreenState();
}

class _MyMagasinScreenState extends State<MyMagasinScreen> {
  List<Magasin> _magasins = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMagasins();
  }

  Future<void> _loadMagasins() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await MagasinService().getMyMagasins();
      if (mounted) setState(() => _magasins = list);
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(Magasin m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Supprimer le magasin',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${m.nom}" ? Cette action est irréversible.',
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
      await MagasinService().deleteMagasin(m.id);
      setState(() => _magasins.removeWhere((x) => x.id == m.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Magasin supprimé'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mes magasins'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadMagasins,
              color: AppTheme.primaryOrange,
              child: _magasins.isEmpty ? _buildEmpty() : _buildList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-magasin'),
        backgroundColor: AppTheme.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nouveau magasin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildList() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    itemCount: _magasins.length,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (_, i) => _MagasinCard(
      magasin: _magasins[i],
      onView: () => context.push('/magasins/${_magasins[i].id}'),
      onEdit: () => context.go('/edit-magasin/${_magasins[i].id}'),
      onDelete: () => _confirmDelete(_magasins[i]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 44,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aucun magasin',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Créez votre premier magasin pour regrouper vos annonces.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.gray500),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.go('/create-magasin'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Créer mon magasin',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: AppTheme.gray400),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.gray600, fontSize: 14),
          ),
          const SizedBox(height: 20),
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
}

// ─── Carte magasin ─────────────────────────────────────────────────────────────

class _MagasinCard extends StatelessWidget {
  final Magasin magasin;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MagasinCard({
    required this.magasin,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: [
          // Bannière
          Container(
            height: 70,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFF22C55E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              children: [
                if (!magasin.isActive)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Inactif',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (magasin.isVerified)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 11,
                            color: Color(0xFF22C55E),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Vérifié',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Contenu
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrangeLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.gray200, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: magasin.logoAbsoluteUrl != null
                        ? Image.network(
                            magasin.logoAbsoluteUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _logoPlaceholder(),
                          )
                        : _logoPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        magasin.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.gray900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        magasin.categorieDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppTheme.gray400,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            magasin.villeDisplay,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.gray500,
                            ),
                          ),
                          if (magasin.marcheDisplay?.isNotEmpty ?? false) ...[
                            const Text(
                              ' · ',
                              style: TextStyle(color: AppTheme.gray400),
                            ),
                            Expanded(
                              child: Text(
                                magasin.marcheDisplay!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.gray500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 12,
                            color: AppTheme.gray400,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${magasin.nbAnnonces} annonce(s) active(s)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.gray500,
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
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.visibility_outlined,
                    label: 'Voir',
                    color: AppTheme.primaryOrange,
                    onTap: onView,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Modifier',
                    color: AppTheme.infoBlue,
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.delete_outline,
                  label: '',
                  color: AppTheme.errorRed,
                  onTap: onDelete,
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() => Center(
    child: Text(
      magasin.initials,
      style: const TextStyle(
        color: AppTheme.primaryOrange,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: compact ? 10 : 0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          if (label.isNotEmpty) ...[
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
        ],
      ),
    ),
  );
}
