// lib/screens/premium/premium_screen.dart
//
// Flow : plans → form → processing → polling → success | failed
// Miroir du composant Angular activate-premium.ts

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/premium.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/premium_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constantes de paiement
// ─────────────────────────────────────────────────────────────────────────────

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
];

// ─────────────────────────────────────────────────────────────────────────────
// Étapes du flow (identiques à l'Angular)
// ─────────────────────────────────────────────────────────────────────────────

enum _Step { plans, form, processing, polling, success, failed }

// ─────────────────────────────────────────────────────────────────────────────
// Écran principal
// ─────────────────────────────────────────────────────────────────────────────

class PremiumScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const PremiumScreen({super.key, this.onBack});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  User? _user;
  PremiumStatus? _status;
  List<PremiumPlan> _plans = [];

  _Step _step = _Step.plans;
  PremiumPlan? _selectedPlan;
  _PaymentMethod _selectedPayment = _paymentMethods[0];

  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loadingPlans = true;
  bool _submitting = false;
  String _statusMessage = '';
  String? _errorMessage;

  SubscribeResponse? _subscribeResponse;
  PremiumSubscription? _successSubscription;

  // ── Polling (miroir de _pollTimer Angular) ─────────────────────────────────
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _pollMax = 24; // 24 × 5 s = 2 min

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _headerCtrl;
  late AnimationController _cardsCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late List<Animation<double>> _cardAnims;

  // ─────────────────────────────────────────────────────────────────────────
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
    _stopPolling();
    _phoneCtrl.dispose();
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Chargement initial : plans + statut premium
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _loadingPlans = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        PremiumService().getPlans(),
        PremiumService().checkStatus(),
      ]);
      final plans = results[0] as List<PremiumPlan>;
      final status = results[1] as PremiumStatus;
      final finalPlans = plans.isNotEmpty ? plans : _fallbackPlans;

      if (mounted) {
        setState(() {
          _plans = finalPlans;
          _status = status;
          _loadingPlans = false;
        });
        _headerCtrl.forward();
        _cardsCtrl.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _plans = _fallbackPlans;
          _loadingPlans = false;
        });
        _headerCtrl.forward();
        _cardsCtrl.forward();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Soumission : crée l'abonnement + ouvre le paiement
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onSubmit() async {
    if (_selectedPlan == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _step = _Step.processing;
      _errorMessage = null;
      _statusMessage = 'Initialisation du paiement…';
      _submitting = true;
    });

    try {
      final response = await PremiumService().subscribe(
        planId: _selectedPlan!.id,
        paymentMethod: _selectedPayment.value,
        phoneNumber: _phoneCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _subscribeResponse = response;
        _statusMessage = 'Ouverture de la page de paiement…';
      });

      // Ouvrir l'URL de paiement FedaPay dans le navigateur
      await _openPaymentUrl(response.paymentUrl);

      // Passer en polling dès que l'URL est ouverte
      if (mounted) {
        setState(() {
          _step = _Step.polling;
          _statusMessage = 'Vérification de votre paiement…';
          _submitting = false;
        });
        _startPolling(response.subscriptionId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.failed;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  Future<void> _openPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Polling (toutes les 5 s, max 2 min — identique à Angular)
  // ─────────────────────────────────────────────────────────────────────────

  void _startPolling(int subscriptionId) {
    _pollCount = 0;
    // Premier appel immédiat
    _tryActivate(subscriptionId);
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollCount++;
      _tryActivate(subscriptionId);
      if (_pollCount >= _pollMax) {
        _stopPolling();
        if (mounted && _step == _Step.polling) {
          setState(() {
            _step = _Step.failed;
            _errorMessage =
                'La confirmation du paiement prend du temps. '
                'Si vous avez payé, votre abonnement sera activé '
                'automatiquement dans quelques minutes.';
          });
        }
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _tryActivate(int subscriptionId) async {
    if (_step == _Step.success) {
      _stopPolling();
      return;
    }
    try {
      final sub = await PremiumService().activateSubscription(subscriptionId);
      if (sub.status == 'active' && mounted) {
        _stopPolling();
        setState(() {
          _successSubscription = sub;
          _step = _Step.success;
        });
      }
      // status != 'active' → encore pending, le polling continue
    } catch (_) {
      // On ignore les erreurs transitoires (réseau) — le polling continue
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions UI
  // ─────────────────────────────────────────────────────────────────────────

  void _selectPlan(PremiumPlan plan) {
    setState(() {
      _selectedPlan = plan;
      _step = _Step.form;
      _errorMessage = null;
    });
  }

  void _goBackToPlans() {
    setState(() {
      _step = _Step.plans;
      _errorMessage = null;
    });
  }

  void _retry() {
    _stopPolling();
    setState(() {
      _step = _Step.form;
      _errorMessage = null;
      _statusMessage = '';
    });
  }

  void _checkNow() {
    final id = _subscribeResponse?.subscriptionId;
    if (id != null) _tryActivate(id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build principal
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.plans:
        return _buildPlansView();
      case _Step.form:
        return _buildFormView();
      case _Step.processing:
        return _buildProcessingView();
      case _Step.polling:
        return _buildPollingView();
      case _Step.success:
        return _buildSuccessView();
      case _Step.failed:
        return _buildFailedView();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP : plans
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPlansView() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (_status?.isPremium == true) ...[
                _buildActiveSubscriptionCard(),
              ] else ...[
                _buildBenefitsSection(),
                const SizedBox(height: 24),
                _SectionTitle(title: '💎 Choisissez votre plan'),
                const SizedBox(height: 16),
                if (_loadingPlans)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  )
                else
                  ..._plans.map(
                    (plan) => _PlanCard(
                      plan: plan,
                      isSelected: false,
                      isPopular: plan.planType == 'unlimited',
                      onTap: () => _selectPlan(plan),
                    ),
                  ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP : form
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFormView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryOrange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: _goBackToPlans,
        ),
        title: const Text(
          'Paiement',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé du plan sélectionné
            _buildPlanSummary(),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              _buildErrorBanner(_errorMessage!),
              const SizedBox(height: 16),
            ],
            // Formulaire de paiement
            _buildPaymentForm(),
            const SizedBox(height: 20),
            _buildSecurityNote(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummary() {
    final plan = _selectedPlan!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.isUnlimited ? 'Illimité' : '${plan.maxAds} annonces'}'
                  ' · ${plan.durationLabel}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.gray500),
                ),
              ],
            ),
          ),
          Text(
            plan.formattedPrice,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Form(
      key: _formKey,
      child: _AnimatedCard(
        animation: _cardAnims[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: '💳 Moyen de paiement'),
            const SizedBox(height: 16),

            // Choix méthode
            Row(
              children: _paymentMethods.map((method) {
                final isSelected = _selectedPayment.value == method.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPayment = method),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                        right: method != _paymentMethods.last ? 10 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
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
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            method.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            method.label,
                            style: TextStyle(
                              fontSize: 11,
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
            const SizedBox(height: 20),

            // Notice FedaPay
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.infoBlueLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.infoBlue,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Comment ça fonctionne ?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...[
                    '1. Cliquez sur « Payer »',
                    '2. Vous êtes redirigé vers la page de paiement sécurisée',
                    '3. Confirmez le paiement sur votre téléphone',
                    '4. Votre abonnement Premium est activé automatiquement',
                  ].map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bouton payer
            GestureDetector(
              onTap: _onSubmit,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFFFAB40)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryOrange.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Payer ${_selectedPlan?.formattedPrice ?? ''} →',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
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

  // ─────────────────────────────────────────────────────────────────────────
  // STEP : processing
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProcessingView() => _buildCenteredStep(
    icon: const CircularProgressIndicator(
      color: AppTheme.primaryOrange,
      strokeWidth: 3,
    ),
    iconBg: const Color(0xFFFFF3E0),
    title: 'Initialisation du paiement…',
    subtitle: _statusMessage,
    extra: _subscribeResponse != null
        ? _buildReferenceChip(
            _subscribeResponse!.reference,
            _subscribeResponse!.amount,
          )
        : null,
    footer: const Text(
      'Ne fermez pas cette page',
      style: TextStyle(fontSize: 12, color: AppTheme.gray400),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // STEP : polling
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPollingView() {
    return _buildCenteredStep(
      icon: const CircularProgressIndicator(
        color: Color(0xFFF59E0B),
        strokeWidth: 3,
      ),
      iconBg: const Color(0xFFFEF3C7),
      title: 'En attente de confirmation',
      subtitle:
          'Nous attendons la confirmation de votre paiement.\nCela peut prendre quelques secondes.',
      extra: _subscribeResponse != null
          ? _buildReferenceChip(
              _subscribeResponse!.reference,
              _subscribeResponse!.amount,
            )
          : null,
      footer: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _checkNow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: AppTheme.primaryOrange,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Vérifier maintenant',
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Si vous avez payé, votre abonnement sera\nactivé automatiquement.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.gray400),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP : success
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSuccessView() {
    final sub = _successSubscription;
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
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Bienvenue au Premium ! 🎉',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.gray900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (sub != null) ...[
                Text(
                  'Votre abonnement ${sub.plan.name} est actif.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (sub.endDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Expire le ${_formatDate(sub.endDate!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.gray400,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryOrange.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vos avantages :',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...([
                      sub?.plan.isUnlimited == true
                          ? 'Annonces illimitées'
                          : '${sub?.plan.maxAds} annonces actives',
                      'Meilleure visibilité dans les recherches',
                      'Badge Premium sur votre profil',
                    ]).map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.successGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t,
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                      'Accéder au Dashboard',
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

  // ─────────────────────────────────────────────────────────────────────────
  // STEP : failed
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFailedView() => _buildCenteredStep(
    icon: const Icon(Icons.close_rounded, color: AppTheme.errorRed, size: 48),
    iconBg: AppTheme.errorRedLight,
    title: 'Paiement non confirmé',
    subtitle: _errorMessage ?? "Le paiement n'a pas abouti.",
    footer: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.onBack ?? () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.gray200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Retour',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _retry,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Réessayer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Widgets réutilisables
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCenteredStep({
    required Widget icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    Widget? extra,
    Widget? footer,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Center(child: icon),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.gray900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (extra != null) ...[const SizedBox(height: 20), extra],
            if (footer != null) ...[const SizedBox(height: 24), footer],
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceChip(String reference, double amount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Référence : ',
                style: TextStyle(fontSize: 12, color: AppTheme.gray500),
              ),
              Text(
                reference,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Montant : ',
                style: TextStyle(fontSize: 12, color: AppTheme.gray500),
              ),
              Text(
                _formatPrice(amount),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionCard() {
    final sub = _status?.activeSubscription;
    return Container(
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
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: Colors.white, size: 32),
              SizedBox(width: 14),
              Expanded(
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
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${sub.daysRemaining} jours restants · ${sub.plan.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return _AnimatedCard(
      animation: _cardAnims[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '🚀 Avantages Premium'),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.65,
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

  Widget _buildErrorBanner(String msg) {
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
              msg,
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

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successGreenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: AppTheme.successGreenDark,
            size: 18,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Paiement sécurisé via FedaPay. Vos données sont protégées.',
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

  // ─────────────────────────────────────────────────────────────────────────
  // AppBar commun
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.primaryOrange,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _formatPrice(double price) {
    final s = price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$s FCFA';
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return isoDate;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Plans de fallback (utilisés si l'API est indisponible)
  // ─────────────────────────────────────────────────────────────────────────

  static final List<PremiumPlan> _fallbackPlans = [
    PremiumPlan(
      id: 1,
      name: 'Premium Basic',
      planType: 'basic',
      price: 1000,
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
      price: 5000,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets locaux
// ─────────────────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? AppTheme.primaryOrange : AppTheme.gray200,
          width: isPopular ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPopular)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFF97316)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '⭐ Recommandé',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gray900,
                        ),
                      ),
                    ],
                  ),
                ),
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
                    plan.isUnlimited ? '∞ Illimité' : '${plan.maxAds} annonces',
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
            const SizedBox(height: 10),
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
              ],
            ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.gray200),
              const SizedBox(height: 10),
              ...plan.features
                  .take(3)
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.successGreen,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
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
                    ),
                  ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF97316), Color(0xFFFFAB40)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Choisir ce plan',
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
      ),
    ),
  );
}

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
