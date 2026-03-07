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
    price: (json['price'] ?? 0).toDouble(),
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
}

/// Abonnement actif de l'utilisateur
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
        plan: PremiumPlan.fromJson(json['plan'] ?? {}),
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

/// Statut premium de l'utilisateur
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
        ? PremiumSubscription.fromJson(json['active_subscription'])
        : null,
  );
}

/// Réponse après souscription
class SubscribeResponse {
  final String message;
  final PremiumSubscription subscription;
  final PaymentInfo paymentInfo;

  const SubscribeResponse({
    required this.message,
    required this.subscription,
    required this.paymentInfo,
  });

  factory SubscribeResponse.fromJson(Map<String, dynamic> json) =>
      SubscribeResponse(
        message: json['message'] ?? '',
        subscription: PremiumSubscription.fromJson(json['subscription'] ?? {}),
        paymentInfo: PaymentInfo.fromJson(json['payment_info'] ?? {}),
      );
}

/// Informations de paiement retournées par l'API
class PaymentInfo {
  final String method;
  final String phone;
  final double amount;
  final String reference;
  final List<String> instructions;

  const PaymentInfo({
    required this.method,
    required this.phone,
    required this.amount,
    required this.reference,
    required this.instructions,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    final instrMap = json['instructions'] as Map<String, dynamic>? ?? {};
    final instrList = instrMap['instructions'] as List<dynamic>? ?? [];
    return PaymentInfo(
      method: json['method'] ?? '',
      phone: json['phone'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      reference: json['reference'] ?? '',
      instructions: instrList.map((e) => e.toString()).toList(),
    );
  }
}
