// lib/screens/premium/premium_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../models/premium.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/premium_service.dart';

// ── Méthodes de paiement disponibles ─────────────────────────────────────────

class _PaymentMethod {
  final String value;
  final String label;
  final String emoji;
  final Color color;
  final String hint;

  const _PaymentMethod({
    required this.value,
    required this.label,
    required this.emoji,
    required this.color,
    required this.hint,
  });
}

const _paymentMethods = [
  _PaymentMethod(
    value: 'wave',
    label: 'Wave',
    emoji: '🌊',
    color: Color(0xFF1E90FF),
    hint: 'Ex: 0700000000',
  ),
  _PaymentMethod(
    value: 'orange_money',
    label: 'Orange Money',
    emoji: '🟠',
    color: Color(0xFFFF6600),
    hint: 'Ex: 0700000000',
  ),
  _PaymentMethod(
    value: 'mtn_money',
    label: 'MTN Money',
    emoji: '💛',
    color: Color(0xFFFFCC00),
    hint: 'Ex: 0700000000',
  ),
];

// ── Écran Principal Premium ───────────────────────────────────────────────────

class PremiumScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PremiumScreen({super.key, this.onBack});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with TickerProviderStateMixin {
  User? _user;
  PremiumStatus? _status;

  List<PremiumPlan> _plans = [];
  PremiumPlan? _selectedPlan;
  _PaymentMethod _selectedPayment = _paymentMethods[0];

  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loadingPlans = true;
  bool _subscribing = false;
  bool _success = false;
  SubscribeResponse? _subscribeResult;
  String? _error;

  late AnimationController _headerCtrl;
  late AnimationController _cardsCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late List<Animation<double>> _cardAnims;

  @override
  void initState() {
    super.initState();
    _user = AuthService().currentUser;

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));

    _cardsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cardAnims = List.generate(4, (i) {
      final start = i * 0.12;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _cardsCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _loadData();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingPlans = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        PremiumService().getPlans(),
        PremiumService().checkStatus(),
      ]);
      final plans = results[0] as List<PremiumPlan>;
      final status = results[1] as PremiumStatus;

      // Plans statiques de fallback si l'API renvoie vide
      final finalPlans = plans.isNotEmpty ? plans : _fallbackPlans;

      if (mounted) {
        setState(() {
          _plans = finalPlans;
          _status = status;
          _selectedPlan = finalPlans.isNotEmpty ? finalPlans[0] : null;
          _loadingPlans = false;
        });
        _headerCtrl.forward();
        _cardsCtrl.forward();
      }
    } catch (e) {
      // En cas d'erreur API, utiliser les plans statiques
      if (mounted) {
        setState(() {
          _plans = _fallbackPlans;
          _selectedPlan = _fallbackPlans[0];
          _loadingPlans = false;
        });
        _headerCtrl.forward();
        _cardsCtrl.forward();
      }
    }
  }

  // Plans de fallback si l'API n'est pas disponible
  static final List<PremiumPlan> _fallbackPlans = [
    PremiumPlan(
      id: 1,
      name: 'Premium Basic',
      planType: 'basic',
      price: 5000,
      currency: 'XOF',
      maxAds: 20,
      durationDays: 30,
      description: 'Parfait pour débuter',
      features: [
        'Jusqu\'à 20 annonces actives',
        'Mise en avant prioritaire',
        'Badge "Premium"',
        'Support prioritaire',
      ],
    ),
    PremiumPlan(
      id: 2,
      name: 'Premium Illimité',
      planType: 'unlimited',
      price: 10000,
      currency: 'XOF',
      maxAds: null,
      durationDays: 30,
      description: 'Pour les vendeurs actifs',
      features: [
        'Annonces illimitées',
        'Position prioritaire dans les résultats',
        'Badge "Premium ⭐"',
        'Statistiques avancées',
        'Support dédié 24/7',
      ],
    ),
  ];

  Future<void> _subscribe() async {
    if (_selectedPlan == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _subscribing = true;
      _error = null;
    });

    try {
      final result = await PremiumService().subscribe(
        planId: _selectedPlan!.id,
        paymentMethod: _selectedPayment.value,
        phoneNumber: _phoneCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _subscribing = false;
          _success = true;
          _subscribeResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _subscribing = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
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
        body: _success
            ? _buildSuccessView()
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 24),
                        if (_status?.isPremium == true)
                          _buildActiveCard()
                        else ...[
                          _buildBenefitsSection(),
                          const SizedBox(height: 28),
                          _buildPlansSection(),
                          const SizedBox(height: 28),
                          _buildPaymentSection(),
                          const SizedBox(height: 16),
                          if (_error != null) _buildErrorBanner(),
                          const SizedBox(height: 20),
                          _buildSubmitButton(),
                          const SizedBox(height: 20),
                          _buildSecurityNote(),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── AppBar dégradé ────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFFF97316),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8C00), Color(0xFFF97316), Color(0xFFFFD700)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Cercles décoratifs
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -40,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              SafeArea(
                child: FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Passer au Premium',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Boostez vos ventes sur Éburnie-Market',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 13,
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
                ),
              ),
            ],
          ),
        ),
      ),
      title: const Text(
        'Premium',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    );
  }

  // ── Carte abonnement actif ─────────────────────────────────────────────────

  Widget _buildActiveCard() {
    final sub = _status?.activeSubscription;
    return _AnimatedCard(
      animation: _cardAnims[0],
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryOrange.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✨ Compte Premium Actif',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Profitez de tous vos avantages',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (sub != null) ...[
              const SizedBox(height: 20),
              const Divider(color: Colors.white30),
              const SizedBox(height: 14),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: '${sub.daysRemaining} jours restants',
                  ),
                  const SizedBox(width: 10),
                  _InfoChip(icon: Icons.star_rounded, label: sub.plan.name),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Votre abonnement est actif 🎉',
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
  }

  // ── Section Avantages ─────────────────────────────────────────────────────

  Widget _buildBenefitsSection() {
    return _AnimatedCard(
      animation: _cardAnims[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: '🚀 Avantages Premium'),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: const [
              _BenefitTile(
                icon: Icons.trending_up_rounded,
                title: 'Plus de visibilité',
                subtitle: 'Annonces en tête des résultats',
                color: Color(0xFFF97316),
              ),
              _BenefitTile(
                icon: Icons.all_inclusive_rounded,
                title: 'Annonces illimitées',
                subtitle: 'Publiez sans restriction',
                color: Color(0xFF22C55E),
              ),
              _BenefitTile(
                icon: Icons.verified_outlined,
                title: 'Badge vérifié',
                subtitle: 'Inspirez confiance',
                color: Color(0xFF3B82F6),
              ),
              _BenefitTile(
                icon: Icons.support_agent_rounded,
                title: 'Support prioritaire',
                subtitle: 'Aide dédiée 24/7',
                color: Color(0xFF8B5CF6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Plans ─────────────────────────────────────────────────────────

  Widget _buildPlansSection() {
    return _AnimatedCard(
      animation: _cardAnims[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: '💎 Choisissez votre plan'),
          const SizedBox(height: 16),
          if (_loadingPlans)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppTheme.primaryOrange),
              ),
            )
          else
            Column(
              children: _plans.asMap().entries.map((entry) {
                final plan = entry.value;
                final isSelected = _selectedPlan?.id == plan.id;
                final isPopular = plan.planType == 'unlimited';
                return _PlanCard(
                  plan: plan,
                  isSelected: isSelected,
                  isPopular: isPopular,
                  onTap: () => setState(() => _selectedPlan = plan),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Section Paiement ──────────────────────────────────────────────────────

  Widget _buildPaymentSection() {
    return _AnimatedCard(
      animation: _cardAnims[2],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: '💳 Moyen de paiement'),
            const SizedBox(height: 16),

            // Méthodes de paiement
            Row(
              children: _paymentMethods.map((method) {
                final isSelected = _selectedPayment.value == method.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPayment = method),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                        right: method != _paymentMethods.last ? 8 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? method.color.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? method.color : AppTheme.gray200,
                          width: isSelected ? 2 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: method.color.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            method.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            method.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? method.color
                                  : AppTheme.gray600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Numéro de téléphone
            Text(
              'Numéro ${_selectedPayment.label}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray700,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 15, color: AppTheme.gray900),
              decoration: InputDecoration(
                hintText: _selectedPayment.hint,
                prefixIcon: Icon(
                  Icons.phone_rounded,
                  color: _selectedPayment.color,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppTheme.gray200,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppTheme.gray200,
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _selectedPayment.color,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppTheme.errorRed,
                    width: 2,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Numéro requis';
                if (v.length < 8) return 'Numéro invalide (min. 8 chiffres)';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.infoBlueLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.infoBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Instructions de paiement',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...[
                          'Assurez-vous d\'avoir suffisamment de fonds',
                          'Vous recevrez une notification sur votre téléphone',
                          'Validez le paiement dans les 5 minutes',
                        ].map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    color: Color(0xFF1E40AF),
                                    fontSize: 12,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1E40AF),
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
          ],
        ),
      ),
    );
  }

  // ── Bannière d'erreur ─────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorRedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bouton de souscription ────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    final plan = _selectedPlan;
    final label = plan != null
        ? 'Souscrire — ${plan.formattedPrice} / ${plan.durationLabel}'
        : 'Choisissez un plan';

    return GestureDetector(
      onTap: _subscribing || plan == null ? null : _subscribe,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: plan != null && !_subscribing
              ? const LinearGradient(
                  colors: [Color(0xFFF97316), Color(0xFFFFAB40)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: plan == null || _subscribing ? AppTheme.gray400 : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: plan != null && !_subscribing
              ? [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: _subscribing
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Traitement en cours...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Note de sécurité ──────────────────────────────────────────────────────

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successGreenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppTheme.successGreenDark,
            size: 18,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Paiement sécurisé via Mobile Money. Vos données sont protégées.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.successGreenDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vue de succès ─────────────────────────────────────────────────────────

  Widget _buildSuccessView() {
    final result = _subscribeResult;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFFFFF), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFF97316)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryOrange.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Souscription initiée ! 🎉',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.gray900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                result?.message ??
                    'Votre demande d\'abonnement Premium a été enregistrée.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.gray500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (result?.paymentInfo.instructions.isNotEmpty == true) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_rounded,
                            color: AppTheme.infoBlue,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Étapes de paiement',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.gray900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...result!.paymentInfo.instructions.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.gray600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (result.paymentInfo.reference.isNotEmpty) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Text(
                              'Référence : ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.gray500,
                              ),
                            ),
                            Text(
                              result.paymentInfo.reference,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.gray900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              GestureDetector(
                onTap: widget.onBack ?? () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Retour au Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
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

// ─── Widgets locaux ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Row(
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
        ),
      ),
    ],
  );
}

class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
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

class _PlanCard extends StatelessWidget {
  final PremiumPlan plan;
  final bool isSelected;
  final bool isPopular;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.isPopular,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryOrange : AppTheme.gray200,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppTheme.primaryOrange.withOpacity(0.12)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Radio
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryOrange
                            : AppTheme.gray400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppTheme.primaryOrange
                            : AppTheme.gray900,
                      ),
                    ),
                  ),
                  if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFF97316)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '⭐ Populaire',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.formattedPrice,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '/ ${plan.durationLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: plan.isUnlimited
                          ? AppTheme.successGreenLight
                          : AppTheme.infoBlueLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      plan.isUnlimited
                          ? '∞ Illimité'
                          : '${plan.maxAds} annonces',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: plan.isUnlimited
                            ? AppTheme.successGreenDark
                            : AppTheme.infoBlue,
                      ),
                    ),
                  ),
                ],
              ),
              if (plan.features.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.gray200),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: plan.features
                      .take(3)
                      .map(
                        (f) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.successGreen,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                f,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.gray600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ── Carte animée ───────────────────────────────────────────────────────────────

class _AnimatedCard extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _AnimatedCard({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) => FadeTransition(
        opacity: animation,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)),
          child: c,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
