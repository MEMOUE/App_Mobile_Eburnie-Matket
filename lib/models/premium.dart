// lib/models/premium.dart

/// Plan premium disponible
class PremiumPlan {
  final int id;
  final String name;
  final String planType; // 'basic' | 'unlimited'
  final double price;
  final String currency;
  final int? maxAds; // null = illimité
  final int durationDays;
  final String description;
  final List<String> features;

  const PremiumPlan({
    required this.id,
    required this.name,
    required this.planType,
    required this.price,
    required this.currency,
    this.maxAds,
    required this.durationDays,
    required this.description,
    required this.features,
  });

  bool get isUnlimited => maxAds == null;

  String get formattedPrice {
    final formatted = price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$formatted FCFA';
  }

  String get durationLabel {
    if (durationDays == 30) return '1 mois';
    if (durationDays == 90) return '3 mois';
    if (durationDays == 180) return '6 mois';
    if (durationDays == 365) return '1 an';
    return '$durationDays jours';
  }

  factory PremiumPlan.fromJson(Map<String, dynamic> json) => PremiumPlan(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
    planType: json['plan_type'] ?? 'basic',
    // Le backend peut renvoyer un String "1000.00" (DecimalField DRF)
    price: _parsePrice(json['price']),
    currency: json['currency'] ?? 'XOF',
    maxAds: json['max_ads'],
    durationDays: json['duration_days'] ?? 30,
    description: json['description'] ?? '',
    features:
        (json['features'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
  );

  static double _parsePrice(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Abonnement actif
// ─────────────────────────────────────────────────────────────────────────────

class PremiumSubscription {
  final int id;
  final PremiumPlan plan;
  final String status; // pending | active | expired | cancelled
  final String? startDate;
  final String? endDate;
  final String createdAt;
  final String paymentMethod;
  final String transactionReference;
  final double amountPaid;
  final bool isActive;
  final int daysRemaining;

  const PremiumSubscription({
    required this.id,
    required this.plan,
    required this.status,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.paymentMethod,
    required this.transactionReference,
    required this.amountPaid,
    required this.isActive,
    required this.daysRemaining,
  });

  factory PremiumSubscription.fromJson(Map<String, dynamic> json) =>
      PremiumSubscription(
        id: json['id'] ?? 0,
        plan: PremiumPlan.fromJson(
          json['plan'] is Map ? json['plan'] as Map<String, dynamic> : {},
        ),
        status: json['status'] ?? 'pending',
        startDate: json['start_date'],
        endDate: json['end_date'],
        createdAt: json['created_at'] ?? '',
        paymentMethod: json['payment_method'] ?? '',
        transactionReference: json['transaction_reference'] ?? '',
        amountPaid: (json['amount_paid'] ?? 0).toDouble(),
        isActive: json['is_active'] ?? false,
        daysRemaining: json['days_remaining'] ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Statut premium de l'utilisateur
// ─────────────────────────────────────────────────────────────────────────────

class PremiumStatus {
  final bool isPremium;
  final bool canCreateAd;
  final int remainingAds;
  final int maxFreeAds;
  final PremiumSubscription? activeSubscription;

  const PremiumStatus({
    required this.isPremium,
    required this.canCreateAd,
    required this.remainingAds,
    required this.maxFreeAds,
    this.activeSubscription,
  });

  factory PremiumStatus.fromJson(Map<String, dynamic> json) => PremiumStatus(
    isPremium: json['is_premium'] ?? false,
    canCreateAd: json['can_create_ad'] ?? true,
    remainingAds: json['remaining_ads'] ?? 0,
    maxFreeAds: json['max_free_ads'] ?? 5,
    activeSubscription: json['active_subscription'] != null
        ? PremiumSubscription.fromJson(
            json['active_subscription'] as Map<String, dynamic>,
          )
        : null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Réponse après souscription — alignée avec le contrat FedaPay du backend
// (miroir de SubscribeResponse dans premium.service.ts Angular)
// ─────────────────────────────────────────────────────────────────────────────

class SubscribeResponse {
  /// ID interne de l'abonnement (pour le polling d'activation)
  final int subscriptionId;

  /// Référence de transaction
  final String reference;

  /// ID FedaPay de la transaction
  final int fedapayId;

  /// Token FedaPay à passer à FedaPay.init() / SDK
  final String token;

  /// Clé publique FedaPay (sandbox ou production)
  final String publicKey;

  /// URL de paiement de secours si la popup est bloquée
  final String paymentUrl;

  final double amount;
  final String currency;
  final PremiumPlan plan;

  const SubscribeResponse({
    required this.subscriptionId,
    required this.reference,
    required this.fedapayId,
    required this.token,
    required this.publicKey,
    required this.paymentUrl,
    required this.amount,
    required this.currency,
    required this.plan,
  });

  factory SubscribeResponse.fromJson(Map<String, dynamic> json) =>
      SubscribeResponse(
        subscriptionId: json['subscription_id'] ?? 0,
        reference: json['reference'] ?? '',
        fedapayId: json['fedapay_id'] ?? 0,
        token: json['token'] ?? '',
        publicKey: json['public_key'] ?? '',
        paymentUrl: json['payment_url'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        currency: json['currency'] ?? 'XOF',
        plan: json['plan'] != null
            ? PremiumPlan.fromJson(json['plan'] as Map<String, dynamic>)
            : PremiumPlan(
                id: 0,
                name: '',
                planType: 'basic',
                price: 0,
                currency: 'XOF',
                durationDays: 30,
                description: '',
                features: [],
              ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Réponse de l'endpoint activate/
// ─────────────────────────────────────────────────────────────────────────────

class ActivateResponse {
  final PremiumSubscription subscription;

  const ActivateResponse({required this.subscription});

  factory ActivateResponse.fromJson(Map<String, dynamic> json) =>
      ActivateResponse(
        subscription: PremiumSubscription.fromJson(
          json['subscription'] as Map<String, dynamic>,
        ),
      );
}
