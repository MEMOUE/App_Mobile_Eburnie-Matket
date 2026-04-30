// lib/models/annonce.dart
import '../config/app_config.dart';

/// Image d'une annonce
class AdImage {
  final String id;
  final String imageUrl;
  final int order;
  final bool isPrimary;

  const AdImage({
    required this.id,
    required this.imageUrl,
    required this.order,
    this.isPrimary = false,
  });

  factory AdImage.fromJson(Map<String, dynamic> json) => AdImage(
    id: json['id']?.toString() ?? '',
    imageUrl: json['image_url'] ?? json['image'] ?? '',
    order: json['order'] ?? 0,
    isPrimary: json['is_primary'] ?? false,
  );
}

/// Utilisateur (vendeur) d'une annonce
class AdUser {
  final int id;
  final String fullName;
  final String? avatar;
  final String? phoneNumber;
  final bool isPremium;
  final int totalAds;
  final double averageRating;

  const AdUser({
    required this.id,
    required this.fullName,
    this.avatar,
    this.phoneNumber,
    this.isPremium = false,
    this.totalAds = 0,
    this.averageRating = 0,
  });

  /// URL absolue de l'avatar
  String? get avatarUrl {
    if (avatar == null || avatar!.isEmpty) return null;
    if (avatar!.startsWith('http')) return avatar;
    return '${AppConfig.mediaUrl}$avatar';
  }

  factory AdUser.fromJson(Map<String, dynamic> json) => AdUser(
    id: json['id'] ?? 0,
    fullName: json['full_name'] ?? json['username'] ?? 'Anonyme',
    avatar: json['avatar'],
    phoneNumber: json['phone_number'],
    isPremium: json['is_premium'] ?? false,
    totalAds: json['total_ads'] ?? 0,
    averageRating: (json['average_rating'] ?? 0).toDouble(),
  );
}

/// Modèle principal d'une annonce
class Ad {
  final String id;
  final String title;
  final String? description;
  final double price;
  final bool isNegotiable;
  final String category;
  final String categoryDisplay;
  final String city;
  final String cityDisplay;
  final String? address;
  final bool isFeatured;
  final bool isUrgent;
  final String status;
  final String adType;
  final int viewsCount;
  final int favoritesCount;
  final String? primaryImage;
  final List<AdImage> images;
  final AdUser? user;
  final List<Map<String, dynamic>> relatedAds;
  final String? publishedAt;
  final String? createdAt;
  final String? expiresAt;
  final String? timeSincePublished;
  final String? whatsappNumber;
  final bool isOwner;
  final int? magasinId; // ← NOUVEAU

  const Ad({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.isNegotiable = false,
    required this.category,
    required this.categoryDisplay,
    required this.city,
    required this.cityDisplay,
    this.address,
    this.isFeatured = false,
    this.isUrgent = false,
    this.status = 'active',
    this.adType = 'sell',
    this.viewsCount = 0,
    this.favoritesCount = 0,
    this.primaryImage,
    this.images = const [],
    this.user,
    this.relatedAds = const [],
    this.publishedAt,
    this.createdAt,
    this.expiresAt,
    this.timeSincePublished,
    this.whatsappNumber,
    this.isOwner = false,
    this.magasinId, // ← NOUVEAU
  });

  /// URL de l'image principale (absolue)
  String? get mainImageUrl {
    if (primaryImage != null && primaryImage!.isNotEmpty) {
      if (primaryImage!.startsWith('http')) return primaryImage;
      return '${AppConfig.mediaUrl}$primaryImage';
    }
    if (images.isNotEmpty) {
      final url = images.first.imageUrl;
      if (url.startsWith('http')) return url;
      return '${AppConfig.mediaUrl}$url';
    }
    return null;
  }

  String get formattedPrice {
    final formatted = price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$formatted FCFA';
  }

  String? get contactWhatsApp {
    final n = whatsappNumber ?? user?.phoneNumber;
    if (n == null || n.isEmpty) return null;
    return n;
  }

  String? get contactPhone {
    final n = user?.phoneNumber ?? whatsappNumber;
    if (n == null || n.isEmpty) return null;
    return n;
  }

  static double _parsePrice(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  static AdUser? _parseUser(Map<String, dynamic> json) {
    if (json['user'] != null && json['user'] is Map) {
      return AdUser.fromJson(Map<String, dynamic>.from(json['user']));
    }
    final name = json['user_name'];
    if (name != null && (name as String).isNotEmpty) {
      return AdUser(
        id: json['user_id'] ?? 0,
        fullName: name,
        avatar: json['user_avatar'],
        phoneNumber: json['user_phone'],
      );
    }
    return null;
  }

  factory Ad.fromJson(Map<String, dynamic> json) => Ad(
    id: json['id']?.toString() ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    price: _parsePrice(json['price']),
    isNegotiable: json['is_negotiable'] ?? false,
    category: json['category'] ?? '',
    categoryDisplay: json['category_display'] ?? '',
    city: json['city'] ?? '',
    cityDisplay: json['city_display'] ?? json['city'] ?? '',
    address: json['address'],
    isFeatured: json['is_featured'] ?? false,
    isUrgent: json['is_urgent'] ?? false,
    status: json['status'] ?? 'active',
    adType: json['ad_type'] ?? 'sell',
    viewsCount: json['views_count'] ?? 0,
    favoritesCount: json['favorites_count'] ?? 0,
    primaryImage: json['primary_image'],
    images:
        (json['images'] as List<dynamic>?)
            ?.map((e) => AdImage.fromJson(e))
            .toList() ??
        [],
    user: _parseUser(json),
    relatedAds:
        (json['related_ads'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [],
    publishedAt: json['published_at'] ?? json['created_at'],
    createdAt: json['created_at'],
    expiresAt: json['expires_at'],
    timeSincePublished: json['time_since_published'],
    whatsappNumber: json['whatsapp_number'],
    isOwner: json['is_owner'] ?? false,
    // ← NOUVEAU : magasin_info.id (endpoint détail) ou magasin (endpoint liste)
    magasinId: json['magasin_info'] is Map
        ? (json['magasin_info'] as Map)['id'] as int?
        : (json['magasin'] is int ? json['magasin'] as int? : null),
  );
}

/// Réponse paginée de l'API
class AdsResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<Ad> results;

  const AdsResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  bool get hasMore => next != null;

  factory AdsResponse.fromJson(dynamic json) {
    if (json is List) {
      return AdsResponse(
        count: json.length,
        results: json.map((e) => Ad.fromJson(e)).toList(),
      );
    }
    final map = json as Map<String, dynamic>;
    return AdsResponse(
      count: map['count'] ?? 0,
      next: map['next'],
      previous: map['previous'],
      results:
          (map['results'] as List<dynamic>?)
              ?.map((e) => Ad.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// Données de la page d'accueil
class HomeData {
  final List<Ad> featuredAds;
  final List<Ad> urgentAds;
  final List<Ad> recentAds;
  final List<Map<String, dynamic>> categories;

  const HomeData({
    this.featuredAds = const [],
    this.urgentAds = const [],
    this.recentAds = const [],
    this.categories = const [],
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    List<Ad> parseAdList(String key) =>
        (json[key] as List<dynamic>?)?.map((e) => Ad.fromJson(e)).toList() ??
        [];

    return HomeData(
      featuredAds: parseAdList('featured_ads'),
      urgentAds: parseAdList('urgent_ads'),
      recentAds: parseAdList('recent_ads'),
      categories:
          (json['categories'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }
}
