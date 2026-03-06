// lib/models/ad.dart

class AdImage {
  final String id;
  final String imageUrl;
  final int order;
  final bool isPrimary;

  const AdImage({
    required this.id,
    required this.imageUrl,
    required this.order,
    required this.isPrimary,
  });

  factory AdImage.fromJson(Map<String, dynamic> json) => AdImage(
    id: json['id']?.toString() ?? '',
    imageUrl: json['image_url'] ?? json['image'] ?? '',
    order: json['order'] ?? 0,
    isPrimary: json['is_primary'] ?? false,
  );
}

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
    required this.isPremium,
    required this.totalAds,
    required this.averageRating,
  });

  String? get avatarUrl {
    if (avatar == null) return null;
    if (avatar!.startsWith('http')) return avatar;
    return 'https://www.eburnie-market.com$avatar';
  }

  factory AdUser.fromJson(Map<String, dynamic> json) => AdUser(
    id: json['id'] ?? 0,
    fullName: json['full_name'] ?? json['username'] ?? '',
    avatar: json['avatar'],
    phoneNumber: json['phone_number'],
    isPremium: json['is_premium'] ?? false,
    totalAds: json['total_ads'] ?? 0,
    averageRating: (json['average_rating'] ?? 0).toDouble(),
  );
}

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
  final String? adType;
  final String status;
  final String? address;
  final String? whatsappNumber;
  final bool isFeatured;
  final bool isUrgent;
  final int viewsCount;
  final int favoritesCount;
  final String? primaryImage;
  final List<AdImage> images;
  final AdUser? user;
  final List<Ad> relatedAds;
  final bool isOwner;
  final String? publishedAt;
  final String? createdAt;
  final String? expiresAt;
  final String? timeSincePublished;

  const Ad({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.isNegotiable,
    required this.category,
    required this.categoryDisplay,
    required this.city,
    required this.cityDisplay,
    this.adType,
    required this.status,
    this.address,
    this.whatsappNumber,
    required this.isFeatured,
    required this.isUrgent,
    required this.viewsCount,
    required this.favoritesCount,
    this.primaryImage,
    required this.images,
    this.user,
    required this.relatedAds,
    required this.isOwner,
    this.publishedAt,
    this.createdAt,
    this.expiresAt,
    this.timeSincePublished,
  });

  String get formattedPrice {
    final formatted = price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$formatted FCFA';
  }

  String? get contactWhatsApp => whatsappNumber ?? user?.phoneNumber;

  String? get contactPhone => user?.phoneNumber ?? whatsappNumber;

  /// URL de l'image principale
  String get mainImageUrl =>
      primaryImage ?? (images.isNotEmpty ? images.first.imageUrl : '');

  factory Ad.fromJson(Map<String, dynamic> json) {
    final imagesList = (json['images'] as List<dynamic>? ?? [])
        .map((e) => AdImage.fromJson(e))
        .toList();

    final relatedList = (json['related_ads'] as List<dynamic>? ?? [])
        .map((e) => Ad.fromJson(e))
        .toList();

    return Ad(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      isNegotiable: json['is_negotiable'] ?? false,
      category: json['category'] ?? '',
      categoryDisplay: json['category_display'] ?? '',
      city: json['city'] ?? '',
      cityDisplay: json['city_display'] ?? json['city'] ?? '',
      adType: json['ad_type'],
      status: json['status'] ?? 'active',
      address: json['address'],
      whatsappNumber: json['whatsapp_number'],
      isFeatured: json['is_featured'] ?? false,
      isUrgent: json['is_urgent'] ?? false,
      viewsCount: json['views_count'] ?? 0,
      favoritesCount: json['favorites_count'] ?? 0,
      primaryImage: json['primary_image'],
      images: imagesList,
      user: json['user'] != null ? AdUser.fromJson(json['user']) : null,
      relatedAds: relatedList,
      isOwner: json['is_owner'] ?? false,
      publishedAt: json['published_at'],
      createdAt: json['created_at'],
      expiresAt: json['expires_at'],
      timeSincePublished: json['time_since_published'],
    );
  }
}

class AdsResponse {
  final List<Ad> results;
  final int count;
  final String? next;
  final String? previous;

  const AdsResponse({
    required this.results,
    required this.count,
    this.next,
    this.previous,
  });

  factory AdsResponse.fromJson(dynamic json) {
    // Gère à la fois une liste directe et un objet paginé
    if (json is List) {
      return AdsResponse(
        results: json.map((e) => Ad.fromJson(e)).toList(),
        count: json.length,
      );
    }
    final map = json as Map<String, dynamic>;
    final items = map['results'] ?? map;
    return AdsResponse(
      results: (items as List<dynamic>).map((e) => Ad.fromJson(e)).toList(),
      count: map['count'] ?? (items as List).length,
      next: map['next'],
      previous: map['previous'],
    );
  }
}

class HomeData {
  final List<Ad> featuredAds;
  final List<Ad> urgentAds;
  final List<Ad> recentAds;
  final List<Map<String, dynamic>> categories;

  const HomeData({
    required this.featuredAds,
    required this.urgentAds,
    required this.recentAds,
    required this.categories,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    Ad fromJ(e) => Ad.fromJson(e);
    return HomeData(
      featuredAds: (json['featured_ads'] as List<dynamic>? ?? [])
          .map(fromJ)
          .toList(),
      urgentAds: (json['urgent_ads'] as List<dynamic>? ?? [])
          .map(fromJ)
          .toList(),
      recentAds: (json['recent_ads'] as List<dynamic>? ?? [])
          .map(fromJ)
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}
