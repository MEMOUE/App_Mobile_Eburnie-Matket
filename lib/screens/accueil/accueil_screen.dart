// lib/screens/accueil/accueil_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/annonce.dart';
import '../../models/magasin.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/annonce_service.dart';
import '../../services/magasin_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

class AccueilScreen extends StatefulWidget {
  final VoidCallback? onGoToDashboard;
  final VoidCallback? onGoToLogin;
  final VoidCallback? onGoToRegister;
  final VoidCallback? onGoToSearch;
  final Function(String adId)? onGoToAdDetail;
  final Function(String category)? onGoToCategory;
  final VoidCallback? onGoToNewAd;
  final Function(int magasinId)? onGoToMagasin;
  final VoidCallback? onGoToMagasins;
  final Function(String marcheValue)? onGoToMagasinsByMarche;

  const AccueilScreen({
    super.key,
    this.onGoToDashboard,
    this.onGoToLogin,
    this.onGoToRegister,
    this.onGoToSearch,
    this.onGoToAdDetail,
    this.onGoToCategory,
    this.onGoToNewAd,
    this.onGoToMagasin,
    this.onGoToMagasins,
    this.onGoToMagasinsByMarche,
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
  int _rotationKey = 0;

  List<Magasin> _allMagasins = [];
  List<Magasin> _displayedMagasins = [];
  int _magasinIndex = 0;
  int _magasinKey = 0;

  List<MarcheGroup> _marcheGroups = [];
  MarcheGroup? _currentMarcheGroup;
  int _marcheIndex = 0;
  int _marcheKey = 0;

  Timer? _rotationTimer;
  static const _rotationInterval = Duration(seconds: 10);

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
      icon: '🌾',
      name: 'Agro',
      value: 'agroalimentaire',
      color: Color(0xFF84CC16),
    ),
    _CategoryItem(
      icon: '🐾',
      name: 'Animaux',
      value: 'animaux_produits_animaliers',
      color: Color(0xFFF59E0B),
    ),
  ];

  @override
  void initState() {
    super.initState();
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
    _rotationTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── Chargement ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    _user = AuthService().currentUser;
    try {
      final results = await Future.wait([
        AnnonceService().getHomeData(),
        MagasinService().getMagasins().catchError((_) => <Magasin>[]),
        MagasinService().getMarchesGrouped().catchError((_) => <MarcheGroup>[]),
      ]);
      final homeData = results[0] as HomeData;
      final magasins = results[1] as List<Magasin>;
      final marcheGrp = results[2] as List<MarcheGroup>;
      if (mounted) {
        setState(() {
          _featuredAds = homeData.featuredAds;
          _urgentAds = homeData.urgentAds;
          _recentAds = homeData.recentAds;
          _allMagasins = magasins;
          _marcheGroups = marcheGrp;
          if (_marcheGroups.isNotEmpty) _currentMarcheGroup = _marcheGroups[0];
          _rotateMagasins(init: true);
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
        _startRotationTimer();
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
    }
  }

  // ─── Timers de rotation ──────────────────────────────────────────────────────

  void _startRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(_rotationInterval, (_) {
      _fetchRotatedAds();
      _rotateMagasins();
      _rotateMarches();
    });
  }

  Future<void> _fetchRotatedAds() async {
    if (!mounted) return;
    try {
      final homeData = await AnnonceService().getHomeData();
      if (mounted)
        setState(() {
          _featuredAds = homeData.featuredAds;
          _urgentAds = homeData.urgentAds;
          _rotationKey++;
        });
    } catch (_) {}
  }

  void _rotateMagasins({bool init = false}) {
    if (_allMagasins.isEmpty) return;
    final total = _allMagasins.length;
    final start = _magasinIndex % total;
    final shown = List<Magasin>.generate(
      total < 4 ? total : 4,
      (i) => _allMagasins[(start + i) % total],
    );
    setState(() {
      _displayedMagasins = shown;
      _magasinIndex = (start + 4) % total;
      if (!init) _magasinKey++;
    });
  }

  void _rotateMarches() {
    if (_marcheGroups.isEmpty) return;
    setState(() {
      _marcheIndex = (_marcheIndex + 1) % _marcheGroups.length;
      _currentMarcheGroup = _marcheGroups[_marcheIndex];
      _marcheKey++;
    });
  }

  Future<void> _onRefresh() async {
    _rotationTimer?.cancel();
    _fadeCtrl.reset();
    _magasinIndex = 0;
    _marcheIndex = 0;
    await _loadData();
  }

  // ─── Contacts ───────────────────────────────────────────────────────────────

  Future<void> _launchWhatsApp(Ad ad) async {
    final phone = ad.contactWhatsApp;
    if (phone == null) return;
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final intl = clean.startsWith('225') ? clean : '225$clean';
    final msg = Uri.encodeComponent(
      'Bonjour,\n\nJe suis intéressé(e) par votre annonce "${ad.title}".\nPrix: ${ad.formattedPrice}\n\nVu sur Éburnie-market.com',
    );
    final uri = Uri.parse('https://wa.me/$intl?text=$msg');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final uri = Uri.parse(
      'sms:$phone?body=${Uri.encodeComponent("Bonjour, je suis intéressé(e) par: ${ad.title}")}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ─── Build principal ────────────────────────────────────────────────────────

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
                if (_featuredAds.isNotEmpty)
                  SliverToBoxAdapter(child: _buildFeaturedSection()),
                SliverToBoxAdapter(child: _buildCategoriesSection()),
                if (_displayedMagasins.isNotEmpty)
                  SliverToBoxAdapter(child: _buildMagasinsSection()),
                if (_currentMarcheGroup != null)
                  SliverToBoxAdapter(child: _buildMarchesSection()),
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

  // ─── Top Bar ────────────────────────────────────────────────────────────────

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

  // ─── Barre de recherche ─────────────────────────────────────────────────────

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
          child: const Row(
            children: [
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

  // ─── CTA Publier ────────────────────────────────────────────────────────────

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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

  // ─── Section Vedette ────────────────────────────────────────────────────────

  Widget _buildFeaturedSection() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Annonces en Vedette',
              subtitle: 'Sélection actualisée toutes les 10 secondes',
              onSeeAll: () => widget.onGoToCategory?.call(''),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey('featured_$_rotationKey'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _featuredAds.length.clamp(0, 6),
                    itemBuilder: (_, i) => _AdGridCard(
                      ad: _featuredAds[i],
                      onTap: () =>
                          widget.onGoToAdDetail?.call(_featuredAds[i].id),
                      onWhatsApp: () => _launchWhatsApp(_featuredAds[i]),
                      onCall: () => _launchCall(_featuredAds[i]),
                      onSms: () => _launchSms(_featuredAds[i]),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _RotationIndicator(
              interval: _rotationInterval,
              key: ValueKey('ri_$_rotationKey'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section Catégories ─────────────────────────────────────────────────────

  Widget _buildCategoriesSection() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
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

  // ══ NOS MAGASINS ════════════════════════════════════════════════════════════

  Widget _buildMagasinsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFF22C55E)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nos Magasins',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.gray900,
                        ),
                      ),
                      Text(
                        '${_allMagasins.length} boutique(s) · rotation toutes les 10 s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onGoToMagasins,
                  child: const Row(
                    children: [
                      Text(
                        'Tous les magasins',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.primaryOrange,
                        size: 11,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey('magasins_$_magasinKey'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.05,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _displayedMagasins.length,
                  itemBuilder: (_, i) => _MagasinCard(
                    magasin: _displayedMagasins[i],
                    onTap: () =>
                        widget.onGoToMagasin?.call(_displayedMagasins[i].id),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _RotationIndicator(
            interval: _rotationInterval,
            key: ValueKey('rm_$_magasinKey'),
            label: '🏪 Boutiques actualisées toutes les 10 s',
          ),
        ],
      ),
    );
  }

  // ══ NOS MARCHÉS ═════════════════════════════════════════════════════════════

  Widget _buildMarchesSection() {
    final group = _currentMarcheGroup!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF14B8A6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_city_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nos Marchés',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.gray900,
                        ),
                      ),
                      Text(
                        '${_marcheGroups.length} ville(s) répertoriée(s)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onGoToMagasins,
                  child: const Row(
                    children: [
                      Text(
                        'Voir les magasins',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF22C55E),
                        size: 11,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Corps animé
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey('marche_$_marcheKey'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Bannière ville courante
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22C55E), Color(0xFF14B8A6)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.villeLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${group.marches.length} marché(s) répertorié(s)',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Indicateur progression
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Prochaine ville',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 60,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    minHeight: 3,
                                    backgroundColor: Color(0x33FFFFFF),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Grille des marchés de la ville courante
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio:
                            2.3, // ratio ajusté pour afficher 2 lignes de texte
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: group.marches.length,
                      itemBuilder: (_, i) => _MarcheCard(
                        marche: group.marches[i],
                        villeLabel: group.villeLabel,
                        colorPair: _marcheColors[i % _marcheColors.length],
                        onTap: () => widget.onGoToMagasinsByMarche != null
                            ? widget.onGoToMagasinsByMarche!.call(
                                group.marches[i].value,
                              )
                            : widget.onGoToMagasins?.call(),
                      ),
                    ),
                    // Points de navigation inter-villes
                    if (_marcheGroups.length > 1) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_marcheGroups.length, (i) {
                          final active = _marcheGroups[i].ville == group.ville;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _marcheIndex = i;
                              _currentMarcheGroup = _marcheGroups[i];
                              _marcheKey++;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: active ? 20 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF22C55E)
                                    : AppTheme.gray200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Avantages ──────────────────────────────────────────────────────

  Widget _buildFeaturesSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
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

  // ─── CTA Register ───────────────────────────────────────────────────────────

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

  // ─── Bottom Nav ─────────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                icon: Icons.storefront_rounded,
                label: 'Magasins',
                onTap: widget.onGoToMagasins,
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

// ══════════════════════════════════════════════════════════════════════════════
// Carte Magasin
// ══════════════════════════════════════════════════════════════════════════════

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
          border: Border.all(color: const Color(0xFFFED7AA), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 56,
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
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
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
                            color: Color(0xFF22C55E),
                            size: 9,
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
                  left: 10,
                  bottom: -18,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: magasin.logoAbsoluteUrl != null
                          ? Image.network(
                              magasin.logoAbsoluteUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initials(),
                            )
                          : _initials(),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 22, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      magasin.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.gray900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      magasin.categorieDisplay,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 10,
                          color: AppTheme.gray400,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            magasin.villeDisplay,
                            style: const TextStyle(
                              fontSize: 9,
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
                          '${magasin.nbAnnonces} ann.',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppTheme.gray500,
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              'Voir',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 7,
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

  Widget _initials() => Container(
    color: AppTheme.primaryOrangeLight,
    child: Center(
      child: Text(
        magasin.initials,
        style: const TextStyle(
          color: AppTheme.primaryOrange,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Carte Marché  — barre gauche 36 px, texte fontSize 11, maxLines 2
// ══════════════════════════════════════════════════════════════════════════════

class _MarcheCard extends StatelessWidget {
  final Marche marche;
  final String villeLabel;
  final List<Color> colorPair;
  final VoidCallback onTap;
  const _MarcheCard({
    required this.marche,
    required this.villeLabel,
    required this.colorPair,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.gray200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Barre colorée réduite à 36 px pour libérer de l'espace texte
            Container(
              width: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colorPair,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.store_mall_directory_outlined,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
            // Zone texte — occupe tout l'espace restant
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      marche.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppTheme.gray900,
                        height: 1.2,
                      ),
                      maxLines: 2, // autorise le retour à la ligne
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      villeLabel,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.gray500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 9,
                color: colorPair[0],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Indicateur de rotation
// ══════════════════════════════════════════════════════════════════════════════

class _RotationIndicator extends StatefulWidget {
  final Duration interval;
  final String label;
  const _RotationIndicator({
    super.key,
    required this.interval,
    this.label = '🔄 Sélection actualisée toutes les 10 s',
  });
  @override
  State<_RotationIndicator> createState() => _RotationIndicatorState();
}

class _RotationIndicatorState extends State<_RotationIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.interval)
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _ctrl.value,
                minHeight: 3,
                backgroundColor: AppTheme.gray200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryOrange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: const TextStyle(fontSize: 10, color: AppTheme.gray400),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets réutilisables
// ══════════════════════════════════════════════════════════════════════════════

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
  Widget build(BuildContext context) => Padding(
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
                      child: _AdImage(url: ad.mainImageUrl ?? ''),
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
                          faIcon: FontAwesomeIcons.whatsapp,
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

class _CategoryCell extends StatelessWidget {
  final _CategoryItem item;
  final VoidCallback onTap;
  const _CategoryCell({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
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
  Widget build(BuildContext context) => Container(
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

class _SmallContactBtn extends StatelessWidget {
  final IconData? icon;
  final IconData? faIcon;
  final Color color;
  final VoidCallback onTap;
  final int flex;
  const _SmallContactBtn({
    this.icon,
    this.faIcon,
    required this.color,
    required this.onTap,
    this.flex = 1,
  }) : assert(icon != null || faIcon != null);
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
        child: Center(
          child: faIcon != null
              ? FaIcon(faIcon!, color: Colors.white, size: 13)
              : Icon(icon!, color: Colors.white, size: 14),
        ),
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
      const Text(
        'Impossible de charger les annonces',
        style: TextStyle(
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
