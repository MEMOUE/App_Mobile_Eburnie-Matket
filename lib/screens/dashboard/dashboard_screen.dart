// lib/screens/dashboard/dashboard_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';

// ─── Modèles de données ──────────────────────────────────────────────────────

class DashboardStats {
  final int totalAds;
  final int activeAds;
  final int pendingAds;
  final int totalViews;
  final int remainingAds;
  final int maxFreeAds;

  const DashboardStats({
    this.totalAds = 0,
    this.activeAds = 0,
    this.pendingAds = 0,
    this.totalViews = 0,
    this.remainingAds = 0,
    this.maxFreeAds = 5,
  });

  double get usagePercentage =>
      maxFreeAds > 0 ? (activeAds / maxFreeAds).clamp(0.0, 1.0) : 0.0;
}

// ─── Écran Dashboard ─────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onGoToProfile;
  final VoidCallback? onGoToMyAds;
  final VoidCallback? onGoToNewAd;
  final VoidCallback? onGoToHome;
  final VoidCallback? onLogout;

  const DashboardScreen({
    super.key,
    this.onGoToProfile,
    this.onGoToMyAds,
    this.onGoToNewAd,
    this.onGoToHome,
    this.onLogout,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  User? _user;
  bool _loadingStats = true;
  bool _avatarError = false;
  DashboardStats _stats = const DashboardStats();

  late AnimationController _heroController;
  late AnimationController _cardsController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late List<Animation<double>> _cardAnims;

  @override
  void initState() {
    super.initState();

    // Animation Hero (header)
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    // Animation des cartes (staggered)
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardAnims = List.generate(6, (i) {
      final start = i * 0.10;
      final end = (start + 0.50).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _cardsController,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _loadData();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingStats = true);

    try {
      _user = AuthService().currentUser;
      if (_user == null) {
        _user = await AuthService().getProfile();
      }
    } catch (_) {}

    // Simuler le chargement des stats API
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _stats = DashboardStats(
          totalAds: 3,
          activeAds: 2,
          pendingAds: 1,
          totalViews: 148,
          remainingAds: 3,
          maxFreeAds: 5,
        );
        _loadingStats = false;
      });
      _heroController.forward();
      _cardsController.forward();
    }
  }

  Future<void> _onRefresh() async {
    _heroController.reset();
    _cardsController.reset();
    await _loadData();
  }

  String _getUserInitials() {
    if (_user == null) return '?';
    final f = _user!.firstName?.isNotEmpty == true ? _user!.firstName![0] : '';
    final l = _user!.lastName?.isNotEmpty == true ? _user!.lastName![0] : '';
    return (f + l).toUpperCase().isNotEmpty
        ? (f + l).toUpperCase()
        : _user!.username.isNotEmpty
        ? _user!.username[0].toUpperCase()
        : '?';
  }

  void _confirmLogout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogoutSheet(
        onConfirm: () {
          Navigator.pop(context);
          widget.onLogout?.call();
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: RefreshIndicator(
          color: AppTheme.primaryOrange,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── AppBar / Hero ──────────────────────────────────────
              _buildAppBar(),

              // ── Body ──────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),

                    // Stats
                    _buildStatsSection(),
                    const SizedBox(height: 28),

                    // Actions rapides
                    _buildSectionTitle('Actions rapides'),
                    const SizedBox(height: 14),
                    _buildQuickActions(),
                    const SizedBox(height: 28),

                    // Premium CTA ou barre libre
                    _buildPremiumSection(),
                    const SizedBox(height: 28),

                    // Activité récente
                    _buildSectionTitle('Activité récente'),
                    const SizedBox(height: 14),
                    _buildRecentActivity(),
                    const SizedBox(height: 28),

                    // Bouton déconnexion
                    _buildLogoutButton(),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar avec fond orange et infos utilisateur ──────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      backgroundColor: AppTheme.primaryOrange,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEA6D0A), Color(0xFFF97316), Color(0xFFFFAB40)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Cercles décoratifs en arrière-plan
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),

              // Contenu
              SafeArea(
                child: FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row
                          Row(
                            children: [
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.home_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: widget.onGoToHome,
                                tooltip: 'Accueil',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {},
                                tooltip: 'Notifications',
                              ),
                            ],
                          ),

                          // Avatar + infos
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildAvatar(),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bonjour 👋',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _user?.fullName ?? 'Utilisateur',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.alternate_email,
                                          color: Colors.white.withOpacity(0.7),
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _user?.username ?? '',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.75,
                                              ),
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Bouton éditer profil
                              GestureDetector(
                                onTap: widget.onGoToProfile,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      title: Text(
        _user?.fullName ?? 'Dashboard',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      titleSpacing: 0,
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = _user?.avatarUrl;
    return Stack(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: avatarUrl != null && !_avatarError
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      _avatarError = true;
                      return _avatarPlaceholder();
                    },
                  )
                : _avatarPlaceholder(),
          ),
        ),
        // Badge premium
        if (_user?.isPremiumActive == true)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: AppTheme.primaryOrangeDark,
      child: Center(
        child: Text(
          _getUserInitials(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ── Section Stats ─────────────────────────────────────────────────────────

  Widget _buildStatsSection() {
    if (_loadingStats) {
      return _buildStatsLoading();
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AnimatedStatCard(
                animation: _cardAnims[0],
                icon: Icons.list_alt_rounded,
                value: '${_stats.totalAds}',
                label: 'Total annonces',
                color: AppTheme.primaryOrange,
                bgColor: AppTheme.primaryOrangeLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnimatedStatCard(
                animation: _cardAnims[1],
                icon: Icons.check_circle_outline_rounded,
                value: '${_stats.activeAds}',
                label: 'Actives',
                color: AppTheme.successGreen,
                bgColor: AppTheme.successGreenLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AnimatedStatCard(
                animation: _cardAnims[2],
                icon: Icons.remove_red_eye_outlined,
                value: '${_stats.totalViews}',
                label: 'Vues totales',
                color: AppTheme.infoBlue,
                bgColor: AppTheme.infoBlueLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnimatedStatCard(
                animation: _cardAnims[3],
                icon: Icons.hourglass_empty_rounded,
                value: '${_stats.pendingAds}',
                label: 'En attente',
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsLoading() {
    return Row(
      children: [
        Expanded(child: _SkeletonCard(height: 90)),
        const SizedBox(width: 12),
        Expanded(child: _SkeletonCard(height: 90)),
      ],
    );
  }

  // ── Section Titre ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.gray900,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // ── Actions rapides ───────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return FadeTransition(
      opacity: _cardAnims.length > 4
          ? _cardAnims[4]
          : const AlwaysStoppedAnimation(1),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Nouvelle\nAnnonce',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA6D0A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  badge: _stats.remainingAds > 0
                      ? '${_stats.remainingAds} restant${_stats.remainingAds > 1 ? 's' : ''}'
                      : null,
                  onTap: widget.onGoToNewAd,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.view_list_rounded,
                  label: 'Mes\nAnnonces',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  badge: _stats.totalAds > 0 ? '${_stats.totalAds}' : null,
                  onTap: widget.onGoToMyAds,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Mon\nProfil',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: widget.onGoToProfile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'Vue\nd\'ensemble',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Premium ───────────────────────────────────────────────────────

  Widget _buildPremiumSection() {
    if (_user?.isPremiumActive == true) {
      return _buildPremiumActiveBadge();
    }
    return _buildFreeAccountCard();
  }

  Widget _buildPremiumActiveBadge() {
    return FadeTransition(
      opacity: _cardAnims.length > 5
          ? _cardAnims[5]
          : const AlwaysStoppedAnimation(1),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryOrange.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compte Premium Actif ✨',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Annonces illimitées · Priorité affichage',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeAccountCard() {
    return FadeTransition(
      opacity: _cardAnims.length > 5
          ? _cardAnims[5]
          : const AlwaysStoppedAnimation(1),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppTheme.gray200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.gray200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Compte Gratuit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_stats.activeAds}/${_stats.maxFreeAds} annonces',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _stats.usagePercentage,
                minHeight: 8,
                backgroundColor: AppTheme.gray200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _stats.usagePercentage >= 1.0
                      ? AppTheme.errorRed
                      : AppTheme.primaryOrange,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _stats.remainingAds > 0
                  ? '${_stats.remainingAds} annonce(s) gratuite(s) restante(s)'
                  : 'Limite atteinte — passez au Premium',
              style: TextStyle(
                fontSize: 12,
                color: _stats.remainingAds > 0
                    ? AppTheme.gray500
                    : AppTheme.errorRed,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 16),

            // Bouton Premium
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFFFAB40)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryOrange.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.star_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Passer au Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '→',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'À partir de 5 000 FCFA / mois · Annonces illimitées',
                style: TextStyle(fontSize: 12, color: AppTheme.gray400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Activité récente ──────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    if (_loadingStats) {
      return Column(
        children: List.generate(3, (_) => _SkeletonCard(height: 72, mb: 10)),
      );
    }

    if (_stats.totalAds == 0) {
      return _buildEmptyActivity();
    }

    // Données fictives pour la démo (à remplacer par un vrai appel API)
    final mockAds = [
      _MockAd(
        title: 'iPhone 13 Pro 256GB',
        price: '320 000 FCFA',
        status: 'active',
        views: 42,
        city: 'Abidjan',
      ),
      _MockAd(
        title: 'Moto Honda CB500 2022',
        price: '1 800 000 FCFA',
        status: 'active',
        views: 87,
        city: 'Bouaké',
      ),
      _MockAd(
        title: 'MacBook Pro M2',
        price: '750 000 FCFA',
        status: 'pending',
        views: 19,
        city: 'Abidjan',
      ),
    ];

    return Column(
      children: mockAds
          .map((ad) => _AdActivityCard(ad: ad, onTap: () {}))
          .toList(),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrangeLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_shopping_cart_outlined,
              color: AppTheme.primaryOrange,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune annonce pour l\'instant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Publiez votre première annonce et\ntouchez des milliers d\'acheteurs.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.gray500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: widget.onGoToNewAd,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Créer une annonce',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bouton Déconnexion ────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _confirmLogout,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE4E4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.errorRed.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, color: AppTheme.errorRed, size: 20),
            SizedBox(width: 10),
            Text(
              'Se déconnecter',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte statistique animée ─────────────────────────────────────────────────

class _AnimatedStatCard extends StatelessWidget {
  final Animation<double> animation;
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color bgColor;

  const _AnimatedStatCard({
    required this.animation,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => FadeTransition(
        opacity: animation,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.gray500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tuile action rapide ──────────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final String? badge;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.gradient,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte activité annonce ───────────────────────────────────────────────────

class _AdActivityCard extends StatelessWidget {
  final _MockAd ad;
  final VoidCallback? onTap;

  const _AdActivityCard({required this.ad, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = ad.status == 'active';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
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
          children: [
            // Icône annonce
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.successGreenLight
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.sell_outlined,
                color: isActive
                    ? AppTheme.successGreenDark
                    : const Color(0xFFD97706),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        ad.price,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppTheme.gray400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppTheme.gray400,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        ad.city,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stats vues + statut
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.successGreenLight
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'En attente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? AppTheme.successGreenDark
                          : const Color(0xFFD97706),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      size: 12,
                      color: AppTheme.gray400,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${ad.views}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sheet déconnexion ────────────────────────────────────────────────────────

class _LogoutSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _LogoutSheet({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppTheme.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.errorRedLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AppTheme.errorRed,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Déconnexion',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Êtes-vous sûr de vouloir vous déconnecter de votre compte ?',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: AppTheme.gray100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.gray700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorRed.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Déconnecter',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton loader ──────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  final double height;
  final double mb;
  const _SkeletonCard({required this.height, this.mb = 0});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        margin: EdgeInsets.only(bottom: widget.mb),
        decoration: BoxDecoration(
          color: Color.lerp(AppTheme.gray100, AppTheme.gray200, _anim.value),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ─── Modèle Mock pour la démo ────────────────────────────────────────────────

class _MockAd {
  final String title;
  final String price;
  final String status;
  final int views;
  final String city;
  _MockAd({
    required this.title,
    required this.price,
    required this.status,
    required this.views,
    required this.city,
  });
}
