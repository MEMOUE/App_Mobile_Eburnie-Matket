// lib/screens/magasin/detail_magasin_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/magasin.dart';
import '../../models/annonce.dart';
import '../../services/magasin_service.dart';

class DetailMagasinScreen extends StatefulWidget {
  final int magasinId;

  const DetailMagasinScreen({super.key, required this.magasinId});

  @override
  State<DetailMagasinScreen> createState() => _DetailMagasinScreenState();
}

class _DetailMagasinScreenState extends State<DetailMagasinScreen> {
  Magasin? _magasin;
  List<dynamic> _annonces = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        MagasinService().getMagasin(widget.magasinId),
        MagasinService().getMagasinAnnonces(widget.magasinId),
      ]);
      if (mounted) {
        setState(() {
          _magasin = results[0] as Magasin;
          _annonces = results[1] as List;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _contactWhatsApp() async {
    final phone = _magasin?.whatsapp;
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final intl = clean.startsWith('225') ? clean : '225$clean';
    final msg = Uri.encodeComponent(
      "Bonjour, j'ai trouvé votre magasin \"${_magasin!.nom}\" sur Éburnie-Market.",
    );
    final uri = Uri.parse('https://wa.me/$intl?text=$msg');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callMagasin() async {
    final phone = _magasin?.telephone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap() async {
    if (_magasin?.latitude == null || _magasin?.longitude == null) return;
    final uri = Uri.parse(
      'https://maps.google.com/?q=${_magasin!.latitude},${_magasin!.longitude}',
    );
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange),
        ),
      );
    }
    if (_error != null || _magasin == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Magasin introuvable',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final m = _magasin!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(m),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(m),
                const SizedBox(height: 8),
                if (m.description?.isNotEmpty ?? false) _buildDescription(m),
                const SizedBox(height: 8),
                if (m.hasLocation) _buildLocation(m),
                const SizedBox(height: 8),
                if (m.hasContact) _buildContact(m),
                const SizedBox(height: 8),
                _buildOwner(m),
                const SizedBox(height: 8),
                _buildAnnonces(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !m.isOwner ? _buildContactBar(m) : _buildOwnerBar(m),
    );
  }

  Widget _buildAppBar(Magasin m) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF97316), Color(0xFF22C55E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go('/magasins'),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          // Logo
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: m.logoAbsoluteUrl != null
                                  ? Image.network(
                                      m.logoAbsoluteUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _logoPlaceholder(m),
                                    )
                                  : _logoPlaceholder(m),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.nom,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.categorieDisplay,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                if (m.isVerified)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Vérifié',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
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
        ),
      ),
      title: Text(
        m.nom,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildInfoCard(Magasin m) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _InfoChip(
                icon: Icons.location_on_outlined,
                text: m.villeDisplay,
                color: AppTheme.primaryOrange,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.shopping_bag_outlined,
                text: '${m.nbAnnonces} annonces',
                color: AppTheme.infoBlue,
              ),
            ],
          ),
          if (m.marcheDisplay != null && m.marcheDisplay!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.storefront_outlined,
                  text: m.marcheDisplay!,
                  color: AppTheme.successGreen,
                ),
                if (m.numeroStand != null && m.numeroStand!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.tag_outlined,
                    text: m.numeroStand!,
                    color: AppTheme.gray500,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescription(Magasin m) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'À propos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          m.description ?? '',
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
        ),
      ],
    ),
  );

  Widget _buildLocation(Magasin m) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.map_outlined, color: AppTheme.primaryOrange, size: 20),
            SizedBox(width: 8),
            Text(
              'Localisation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (m.villeDisplay.isNotEmpty)
          _LocationRow(
            icon: Icons.location_city_outlined,
            label: 'Ville',
            value: m.villeDisplay,
          ),
        if (m.marcheDisplay?.isNotEmpty ?? false)
          _LocationRow(
            icon: Icons.storefront_outlined,
            label: 'Marché',
            value: m.marcheDisplay!,
          ),
        if (m.numeroStand?.isNotEmpty ?? false)
          _LocationRow(icon: Icons.tag, label: 'Stand', value: m.numeroStand!),
        if (m.adresse?.isNotEmpty ?? false)
          _LocationRow(
            icon: Icons.home_outlined,
            label: 'Adresse',
            value: m.adresse!,
          ),
        if (m.latitude != null && m.longitude != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _openMap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Voir sur la carte',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildContact(Magasin m) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.phone_outlined, color: AppTheme.primaryOrange, size: 20),
            SizedBox(width: 8),
            Text(
              'Contact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (m.telephone?.isNotEmpty ?? false)
          _ContactRow(
            icon: Icons.phone,
            color: AppTheme.infoBlue,
            text: m.telephone!,
            onTap: _callMagasin,
          ),
        if (m.whatsapp?.isNotEmpty ?? false)
          _ContactRow(
            icon: Icons.chat,
            color: const Color(0xFF25D366),
            text: m.whatsapp!,
            onTap: _contactWhatsApp,
          ),
        if (m.emailContact?.isNotEmpty ?? false)
          _ContactRow(
            icon: Icons.email_outlined,
            color: AppTheme.primaryOrange,
            text: m.emailContact!,
            onTap: () async {
              final uri = Uri.parse('mailto:${m.emailContact}');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
      ],
    ),
  );

  Widget _buildOwner(Magasin m) {
    final owner = m.owner;
    final name = owner?.fullName ?? m.ownerName ?? 'Vendeur';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.person_outline,
                color: AppTheme.primaryOrange,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Vendeur',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                backgroundImage: owner?.avatarUrl != null
                    ? NetworkImage(owner!.avatarUrl!)
                    : null,
                child: owner?.avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (owner?.isPremium ?? false)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⭐ PREMIUM',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnonces() => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Annonces du magasin',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_annonces.length})',
              style: const TextStyle(color: AppTheme.gray400, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_annonces.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    "Ce magasin n'a pas encore d'annonces.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _annonces.length,
              itemBuilder: (_, i) {
                final a = _annonces[i];
                final ad = a is Ad ? a : Ad.fromJson(a as Map<String, dynamic>);
                return _AnnonceMiniCard(
                  ad: ad,
                  onTap: () => context.push('/annonces/${ad.id}'),
                );
              },
            ),
          ),
      ],
    ),
  );

  Widget _buildContactBar(Magasin m) => Container(
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      MediaQuery.of(context).padding.bottom + 12,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Row(
      children: [
        if (m.whatsapp?.isNotEmpty ?? false)
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _contactWhatsApp,
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if ((m.whatsapp?.isNotEmpty ?? false) &&
            (m.telephone?.isNotEmpty ?? false))
          const SizedBox(width: 10),
        if (m.telephone?.isNotEmpty ?? false)
          Expanded(
            child: ElevatedButton(
              onPressed: _callMagasin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.infoBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.phone, size: 20),
            ),
          ),
      ],
    ),
  );

  Widget _buildOwnerBar(Magasin m) => Container(
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      MediaQuery.of(context).padding.bottom + 12,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: ElevatedButton.icon(
      onPressed: () => context.go('/edit-magasin/${m.id}'),
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Modifier mon magasin'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _logoPlaceholder(Magasin m) => Container(
    color: AppTheme.primaryOrangeLight,
    child: Center(
      child: Text(
        m.initials,
        style: const TextStyle(
          color: AppTheme.primaryOrange,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
    ),
  );
}

// ─── Widgets internes ──────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryOrange),
        const SizedBox(width: 8),
        Text(
          '$label : ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.gray700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
          ),
        ),
      ],
    ),
  );
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;
  const _ContactRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AnnonceMiniCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap;
  const _AnnonceMiniCard({required this.ad, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 110,
              width: 140,
              child: ad.mainImageUrl != null
                  ? Image.network(
                      ad.mainImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ad.formattedPrice,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
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
