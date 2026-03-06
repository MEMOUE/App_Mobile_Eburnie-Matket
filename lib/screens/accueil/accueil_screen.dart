// lib/screens/accueil/accueil_screen.dart
// Version avec données RÉELLES de l'API

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/ad.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/annonce_service.dart';

// ── Catégories statiques (icônes/couleurs locales) ──────────────────────────

class _CategoryItem {
  final String icon;
  final String name;
  final String value;
  final Color color;
  const _CategoryItem({
    required this.icon,
    required this.name,
    required this.value,
    required this.color,
  });
}

// ── Écran Accueil ────────────────────────────────────────────────────────────

class AccueilScreen extends StatefulWidget {
  final VoidCallback? onGoToDashboard;
  final VoidCallback? onGoToLogin;
  final VoidCallback? onGoToRegister;
  final VoidCallback? onGoToSearch;
  final Function(String adId)? onGoToAdDetail;
  final Function(String category)? onGoToCategory;
  final VoidCallback? onGoToNewAd;

  const AccueilScreen({
    super.key,
    this.onGoToDashboard,
    this.onGoToLogin,
    this.onGoToRegister,
    this.onGoToSearch,
    this.onGoToAdDetail,
    this.onGoToCategory,
    this.onGoToNewAd,
  });

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen>
    with TickerProviderStateMixin {
  final _scrollCtrl = ScrollController();

  User? _user;
  bool _loading = true;
  bool _avatarError = false;
  String? _errorMessage;

  List<Ad> _featuredAds = [];
  List<Ad> _urgentAds = [];
  List<Ad> _recentAds = [];

  late PageController _bannerPageCtrl;
  int _bannerPage = 0;
  Timer? _bannerTimer;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const List<_CategoryItem> _categories = [
    _CategoryItem(
      icon: '🚗',
      name: 'Véhicules',
      value: 'vehicules',
      color: Color(0xFFEF4444),
    ),
    _CategoryItem(
      icon: '💼',
      name: 'Emploi',
      value: 'emploi_stages',
      color: Color(0xFFEAB308),
    ),
    _CategoryItem(
      icon: '🏠',
      name: 'Immobilier',
      value: 'immobilier',
      color: Color(0xFF22C55E),
    ),
    _CategoryItem(
      icon: '📱',
      name: 'Électronique',
      value: 'electronique',
      color: Color(0xFF3B82F6),
    ),
    _CategoryItem(
      icon: '🛋️',
      name: 'Maison',
      value: 'maison_jardin',
      color: Color(0xFF06B6D4),
    ),
    _CategoryItem(
      icon: '👗',
      name: 'Mode',
      value: 'mode_beaute',
      color: Color(0xFFEC4899),
    ),
    _CategoryItem(
      icon: '⚽',
      name: 'Sport',
      value: 'sport_loisirs',
      color: Color(0xFFF97316),
    ),
    _CategoryItem(
      icon: '🔧',
      name: 'Services',
      value: 'services',
      color: Color(0xFF8B5CF6),
    ),
    _CategoryItem(
      icon: '🌾',
      name: 'Agro',
      value: 'agroalimentaire',
      color: Color(0xFF84CC16),
    ),
    _CategoryItem(
      icon: '🐾',
      name: 'Animaux',
      value: 'animaux',
      color: Color(0xFFF59E0B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bannerPageCtrl = PageController();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _loadData();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _bannerPageCtrl.dispose();
    _bannerTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Chargement des données réelles ─────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    _user = AuthService().currentUser;

    try {
      final homeData = await AnnonceService().getHomeData();
      if (mounted) {
        setState(() {
          _featuredAds = homeData.featuredAds;
          _urgentAds = homeData.urgentAds;
          _recentAds = homeData.recentAds;
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
        _startBannerTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    if (_featuredAds.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (_bannerPageCtrl.hasClients && mounted) {
          final next = (_bannerPage + 1) % _featuredAds.length;
          _bannerPageCtrl.animateToPage(
            next,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _onRefresh() async {
    _fadeCtrl.reset();
    _bannerTimer?.cancel();
    await _loadData();
  }

  // ── Contact ────────────────────────────────────────────────────────────────
  Future<void> _launchWhatsApp(Ad ad) async {
    final phone = ad.contactWhatsApp;
    if (phone == null) return;
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final intl = clean.startsWith('225') ? clean : '225$clean';
    final msg = Uri.encodeComponent(
      'Bonjour,\n\nJe suis intéressé(e) par votre annonce "${ad.title}".\nPrix: ${ad.formattedPrice}\n\nVu sur Éburnie-market.com',
    );
    final uri = Uri.parse('https://wa.me/$intl?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchCall(Ad ad) async {
    final phone = ad.contactPhone;
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchSms(Ad ad) async {
    final phone = ad.contactPhone;
    if (phone == null) return;
    final msg = Uri.encodeComponent(
      'Bonjour, je suis intéressé(e) par: ${ad.title}',
    );
    final uri = Uri.parse('sms:$phone?body=$msg');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Build principal ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: RefreshIndicator(
          color: AppTheme.primaryOrange,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildTopBar(),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildPublishCTA()),
              if (_loading)
                const SliverFillRemaining(child: _LoadingState())
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: _ErrorState(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _buildFeaturedSection()),
                if (_urgentAds.isNotEmpty)
                  SliverToBoxAdapter(child: _buildUrgentSection()),
                if (_recentAds.isNotEmpty)
                  SliverToBoxAdapter(child: _buildRecentSection()),
                SliverToBoxAdapter(child: _buildCategoriesSection()),
                SliverToBoxAdapter(child: _buildFeaturesSection()),
                if (_user == null)
                  SliverToBoxAdapter(child: _buildRegisterCTA()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppTheme.gray200)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFF22C55E)],
                  ).createShader(b),
                  child: const Text(
                    'Éburnie-Market',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Text(
                  'Votre marketplace ivoirienne',
                  style: TextStyle(fontSize: 10, color: AppTheme.gray400),
                ),
              ],
            ),
            const Spacer(),
            if (_user != null)
              GestureDetector(
                onTap: widget.onGoToDashboard,
                child: _TopAvatar(user: _user!, avatarError: _avatarError),
              )
            else
              _TopBtn(
                label: 'Connexion',
                color: AppTheme.successGreen,
                onTap: widget.onGoToLogin,
              ),
          ],
        ),
      ),
    );
  }

  // ── Barre de recherche ─────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: GestureDetector(
        onTap: widget.onGoToSearch,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.gray200, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: const [
              Icon(Icons.search_rounded, color: AppTheme.gray400, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rechercher une annonce...',
                  style: TextStyle(color: AppTheme.gray400, fontSize: 15),
                ),
              ),
              Icon(Icons.tune_rounded, color: AppTheme.primaryOrange, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── CTA Publier ────────────────────────────────────────────────────────────
  Widget _buildPublishCTA() {
    return Container(
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: GestureDetector(
        onTap: widget.onGoToNewAd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF97316), Color(0xFFFFAB40)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryOrange.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Publier une annonce',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Vedettes ───────────────────────────────────────────────────────
  Widget _buildFeaturedSection() {
    if (_featuredAds.isEmpty) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Annonces en Vedette',
            subtitle: 'Meilleures offres du moment',
            onSeeAll: () => widget.onGoToCategory?.call(''),
          ),
          const SizedBox(height: 14),
          // Carrousel bannière
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _bannerPageCtrl,
              onPageChanged: (p) => setState(() => _bannerPage = p),
              itemCount: _featuredAds.length,
              itemBuilder: (_, i) => _BannerCard(
                ad: _featuredAds[i],
                onTap: () => widget.onGoToAdDetail?.call(_featuredAds[i].id),
                onWhatsApp: () => _launchWhatsApp(_featuredAds[i]),
                onCall: () => _launchCall(_featuredAds[i]),
                onSms: () => _launchSms(_featuredAds[i]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Indicateurs de page
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _featuredAds.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == _bannerPage ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _bannerPage
                      ? AppTheme.primaryOrange
                      : AppTheme.gray200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Grille 2 colonnes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _featuredAds.length.clamp(0, 6),
              itemBuilder: (_, i) => _AdGridCard(
                ad: _featuredAds[i],
                onTap: () => widget.onGoToAdDetail?.call(_featuredAds[i].id),
                onWhatsApp: () => _launchWhatsApp(_featuredAds[i]),
                onCall: () => _launchCall(_featuredAds[i]),
                onSms: () => _launchSms(_featuredAds[i]),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Section Urgentes ───────────────────────────────────────────────────────
  Widget _buildUrgentSection() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: const Color(0xFFFFF5F5),
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: '🔥 Annonces Urgentes',
              subtitle: 'Ne ratez pas ces opportunités !',
              titleColor: AppTheme.errorRed,
              onSeeAll: () => widget.onGoToCategory?.call(''),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _urgentAds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _UrgentCard(
                  ad: _urgentAds[i],
                  onTap: () => widget.onGoToAdDetail?.call(_urgentAds[i].id),
                  onWhatsApp: () => _launchWhatsApp(_urgentAds[i]),
                  onCall: () => _launchCall(_urgentAds[i]),
                  onSms: () => _launchSms(_urgentAds[i]),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Section Récentes ───────────────────────────────────────────────────────
  Widget _buildRecentSection() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Annonces Récentes',
              subtitle: 'Publiées ces dernières heures',
              onSeeAll: () => widget.onGoToCategory?.call(''),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _recentAds.length.clamp(0, 6),
                itemBuilder: (_, i) => _AdGridCard(
                  ad: _recentAds[i],
                  onTap: () => widget.onGoToAdDetail?.call(_recentAds[i].id),
                  onWhatsApp: () => _launchWhatsApp(_recentAds[i]),
                  onCall: () => _launchCall(_recentAds[i]),
                  onSms: () => _launchSms(_recentAds[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Catégories ─────────────────────────────────────────────────────
  Widget _buildCategoriesSection() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Catégories Populaires',
              subtitle: 'Explorez par domaine',
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _categories.length,
                itemBuilder: (_, i) => _CategoryCell(
                  item: _categories[i],
                  onTap: () =>
                      widget.onGoToCategory?.call(_categories[i].value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Avantages ──────────────────────────────────────────────────────
  Widget _buildFeaturesSection() {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Pourquoi Éburnie-Market ?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.gray900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: const [
              _FeatureCard(
                icon: Icons.shield_outlined,
                title: 'Sécurisé',
                subtitle: 'Achats et ventes protégés',
              ),
              _FeatureCard(
                icon: Icons.bolt_outlined,
                title: 'Rapide & Simple',
                subtitle: 'Publiez en quelques clics',
              ),
              _FeatureCard(
                icon: Icons.people_outline_rounded,
                title: 'Communauté',
                subtitle: 'Milliers d\'utilisateurs',
              ),
              _FeatureCard(
                icon: Icons.verified_outlined,
                title: 'Vérifié',
                subtitle: 'Annonces contrôlées',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CTA Register ───────────────────────────────────────────────────────────
  Widget _buildRegisterCTA() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryOrange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Prêt à commencer ? 🚀',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Rejoignez des milliers d\'Ivoiriens qui achètent et vendent',
            style: TextStyle(fontSize: 13, color: Colors.white, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _CTAButton(
                  label: 'S\'inscrire',
                  icon: Icons.person_add_outlined,
                  bgColor: Colors.white,
                  textColor: AppTheme.primaryOrange,
                  onTap: widget.onGoToRegister,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CTAButton(
                  label: 'Connexion',
                  icon: Icons.login_rounded,
                  bgColor: const Color(0xFF15803D),
                  textColor: Colors.white,
                  onTap: widget.onGoToLogin,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.gray200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.home_rounded,
                label: 'Accueil',
                active: true,
                onTap: () {},
              ),
              _BottomNavItem(
                icon: Icons.search_rounded,
                label: 'Rechercher',
                onTap: widget.onGoToSearch,
              ),
              GestureDetector(
                onTap: widget.onGoToNewAd,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              _BottomNavItem(
                icon: Icons.list_alt_rounded,
                label: 'Annonces',
                onTap: () => widget.onGoToCategory?.call(''),
              ),
              _BottomNavItem(
                icon: _user != null
                    ? Icons.person_rounded
                    : Icons.login_rounded,
                label: _user != null ? 'Profil' : 'Connexion',
                onTap: _user != null
                    ? widget.onGoToDashboard
                    : widget.onGoToLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets réutilisables ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: titleColor ?? AppTheme.gray900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                ),
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Row(
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppTheme.primaryOrange,
                    size: 12,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Carte bannière ─────────────────────────────────────────────────────────────
class _BannerCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap, onWhatsApp, onCall, onSms;

  const _BannerCard({
    required this.ad,
    required this.onTap,
    required this.onWhatsApp,
    required this.onCall,
    required this.onSms,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _AdImage(url: ad.mainImageUrl),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Row(
                  children: [
                    if (ad.isFeatured)
                      _Badge(label: '⭐ Vedette', color: AppTheme.primaryOrange),
                    if (ad.isUrgent) ...[
                      const SizedBox(width: 6),
                      _Badge(label: '🔥 Urgent', color: AppTheme.errorRed),
                    ],
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ad.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            ad.formattedPrice,
                            style: const TextStyle(
                              color: Color(0xFFFFAB40),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.white60,
                            size: 13,
                          ),
                          Text(
                            ad.cityDisplay,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _ContactBtn(
                            icon: Icons.chat_bubble_outline_rounded,
                            color: const Color(0xFF25D366),
                            label: 'WhatsApp',
                            onTap: onWhatsApp,
                          ),
                          const SizedBox(width: 8),
                          _ContactBtn(
                            icon: Icons.phone_rounded,
                            color: AppTheme.infoBlue,
                            onTap: onCall,
                          ),
                          const SizedBox(width: 8),
                          _ContactBtn(
                            icon: Icons.sms_outlined,
                            color: const Color(0xFF8B5CF6),
                            onTap: onSms,
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
    );
  }
}

// ── Carte grille ───────────────────────────────────────────────────────────────
class _AdGridCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap, onWhatsApp, onCall, onSms;

  const _AdGridCard({
    required this.ad,
    required this.onTap,
    required this.onWhatsApp,
    required this.onCall,
    required this.onSms,
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
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: SizedBox.expand(
                      child: _AdImage(url: ad.mainImageUrl),
                    ),
                  ),
                  if (ad.isFeatured)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Badge(
                        label: '⭐',
                        color: AppTheme.primaryOrange,
                        compact: true,
                      ),
                    ),
                  if (ad.isUrgent)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(
                        label: 'URGENT',
                        color: AppTheme.errorRed,
                        compact: true,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ad.formattedPrice,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 3),
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
                            ad.cityDisplay,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.gray400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.remove_red_eye_outlined,
                          size: 11,
                          color: AppTheme.gray400,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${ad.viewsCount}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.gray400,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _SmallContactBtn(
                          icon: Icons.chat_bubble_outline_rounded,
                          color: const Color(0xFF25D366),
                          onTap: onWhatsApp,
                          flex: 2,
                        ),
                        const SizedBox(width: 4),
                        _SmallContactBtn(
                          icon: Icons.phone_rounded,
                          color: AppTheme.infoBlue,
                          onTap: onCall,
                        ),
                        const SizedBox(width: 4),
                        _SmallContactBtn(
                          icon: Icons.sms_outlined,
                          color: const Color(0xFF8B5CF6),
                          onTap: onSms,
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

// ── Carte urgente ──────────────────────────────────────────────────────────────
class _UrgentCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap, onWhatsApp, onCall, onSms;

  const _UrgentCard({
    required this.ad,
    required this.onTap,
    required this.onWhatsApp,
    required this.onCall,
    required this.onSms,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 185,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.errorRed.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: SizedBox.expand(
                      child: _AdImage(url: ad.mainImageUrl),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _Badge(
                      label: 'URGENT',
                      color: AppTheme.errorRed,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ad.formattedPrice,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 10,
                          color: AppTheme.gray400,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          ad.cityDisplay,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.gray400,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _SmallContactBtn(
                          icon: Icons.chat_bubble_outline_rounded,
                          color: const Color(0xFF25D366),
                          onTap: onWhatsApp,
                          flex: 2,
                        ),
                        const SizedBox(width: 4),
                        _SmallContactBtn(
                          icon: Icons.phone_rounded,
                          color: AppTheme.infoBlue,
                          onTap: onCall,
                        ),
                        const SizedBox(width: 4),
                        _SmallContactBtn(
                          icon: Icons.sms_outlined,
                          color: const Color(0xFF8B5CF6),
                          onTap: onSms,
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

// ── Cellule catégorie ──────────────────────────────────────────────────────────
class _CategoryCell extends StatelessWidget {
  final _CategoryItem item;
  final VoidCallback onTap;
  const _CategoryCell({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(item.icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte feature ──────────────────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: AppTheme.gray500),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget image avec fallback ─────────────────────────────────────────────────
class _AdImage extends StatelessWidget {
  final String url;
  const _AdImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppTheme.primaryOrangeLight,
          child: const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryOrange,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppTheme.primaryOrange.withOpacity(0.5),
          AppTheme.primaryOrangeDark,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Center(
      child: Icon(Icons.image_outlined, color: Colors.white30, size: 32),
    ),
  );
}

// ── Micro-widgets ──────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;
  const _Badge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 6 : 8,
      vertical: compact ? 3 : 4,
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontSize: compact ? 9 : 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback onTap;
  const _ContactBtn({
    required this.icon,
    required this.color,
    this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: label != null ? 12 : 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          if (label != null) ...[
            const SizedBox(width: 5),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SmallContactBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int flex;
  const _SmallContactBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 14)),
      ),
    ),
  );
}

class _TopAvatar extends StatelessWidget {
  final User user;
  final bool avatarError;
  const _TopAvatar({required this.user, required this.avatarError});

  @override
  Widget build(BuildContext context) {
    final fn = user.firstName?.isNotEmpty == true ? user.firstName![0] : '';
    final ln = user.lastName?.isNotEmpty == true ? user.lastName![0] : '';
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryOrange, width: 2),
          ),
          child: ClipOval(
            child: user.avatarUrl != null && !avatarError
                ? Image.network(
                    user.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initials(fn, ln),
                  )
                : _initials(fn, ln),
          ),
        ),
        if (user.isPremiumActive)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: 8,
              ),
            ),
          ),
      ],
    );
  }

  Widget _initials(String fn, String ln) => Container(
    color: AppTheme.primaryOrange,
    child: Center(
      child: Text(
        (fn + ln).toUpperCase().isNotEmpty ? (fn + ln).toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    ),
  );
}

class _TopBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _TopBtn({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ),
  );
}

class _CTAButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor, textColor;
  final VoidCallback? onTap;
  const _CTAButton({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primaryOrange : AppTheme.gray400;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── États de chargement / erreur ───────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircularProgressIndicator(color: AppTheme.primaryOrange),
      SizedBox(height: 16),
      Text(
        'Chargement des annonces...',
        style: TextStyle(color: AppTheme.gray500, fontSize: 14),
      ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.wifi_off_rounded,
        size: 64,
        color: AppTheme.gray200.withOpacity(0.5),
      ),
      const SizedBox(height: 16),
      Text(
        'Impossible de charger les annonces',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppTheme.gray900,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        message,
        style: const TextStyle(color: AppTheme.gray500, fontSize: 13),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: onRetry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Réessayer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );
}
