// lib/services/annonce_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/annonce.dart';
import 'auth_service.dart';

class AnnonceService {
  static final AnnonceService _instance = AnnonceService._internal();
  factory AnnonceService() => _instance;
  AnnonceService._internal();

  String get _baseUrl => '${AppConfig.apiUrl}produit/';

  /// Headers JSON + token si connecté
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (AuthService().token != null)
      'Authorization': 'Token ${AuthService().token}',
  };

  /// Headers sans Content-Type pour les requêtes multipart
  Map<String, String> get _authHeaders => {
    'Accept': 'application/json',
    if (AuthService().token != null)
      'Authorization': 'Token ${AuthService().token}',
  };

  // ─── Page d'accueil ────────────────────────────────────────────────────────

  Future<HomeData> getHomeData() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}home-data/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        return HomeData.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
      throw _parseError(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur de parsing home-data: $e');
    }
  }

  // ─── Liste des annonces ────────────────────────────────────────────────────

  Future<AdsResponse> getAds({
    String? category,
    String? city,
    String? search,
    double? priceMin,
    double? priceMax,
    String ordering = '-created_at',
    int page = 1,
  }) async {
    try {
      final params = <String, String>{};
      if (category != null && category.isNotEmpty)
        params['category'] = category;
      if (city != null && city.isNotEmpty) params['city'] = city;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (priceMin != null) params['price_min'] = priceMin.toString();
      if (priceMax != null) params['price_max'] = priceMax.toString();
      params['ordering'] = ordering;
      params['page'] = page.toString();

      final uri = Uri.parse('${_baseUrl}ads/').replace(queryParameters: params);
      final response = await http
          .get(uri, headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        return AdsResponse.fromJson(
          json.decode(utf8.decode(response.bodyBytes)),
        );
      }
      throw _parseError(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur de parsing ads: $e');
    }
  }

  // ─── Détail d'une annonce ──────────────────────────────────────────────────

  Future<Ad> getAdDetail(String adId) async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}ads/$adId/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        return Ad.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
      throw _parseError(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur de parsing ad detail: $e');
    }
  }

  // ─── Mes annonces ──────────────────────────────────────────────────────────

  Future<List<Ad>> getMyAds() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}my-ads/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) return data.map((e) => Ad.fromJson(e)).toList();
        if (data is Map && data['results'] != null) {
          return (data['results'] as List).map((e) => Ad.fromJson(e)).toList();
        }
        return [];
      }
      throw _parseError(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur de parsing my-ads: $e');
    }
  }

  // ─── Créer une annonce ─────────────────────────────────────────────────────

  Future<Ad> createAd({
    required String title,
    required String description,
    required double price,
    required String category,
    required String city,
    required String adType,
    bool isNegotiable = false,
    bool isUrgent = false,
    String? whatsappNumber,
    String? address,
    String? expiresAt,
    List<File> images = const [],
    int? primaryImageIndex,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}ads/create/'),
    );
    request.headers.addAll(_authHeaders);

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['price'] = price.toStringAsFixed(0);
    request.fields['category'] = category;
    request.fields['city'] = city;
    request.fields['ad_type'] = adType;
    request.fields['is_negotiable'] = isNegotiable.toString();
    request.fields['is_urgent'] = isUrgent.toString();
    if (whatsappNumber != null && whatsappNumber.isNotEmpty) {
      request.fields['whatsapp_number'] = whatsappNumber;
    }
    if (address != null && address.isNotEmpty) {
      request.fields['address'] = address;
    }
    if (expiresAt != null && expiresAt.isNotEmpty) {
      request.fields['expires_at'] = expiresAt;
    }
    for (final img in images) {
      request.files.add(await http.MultipartFile.fromPath('images', img.path));
    }
    if (primaryImageIndex != null) {
      request.fields['primary_image_index'] = primaryImageIndex.toString();
    }

    final streamed = await request.send().timeout(AppConfig.connectTimeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Ad.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    }
    throw _parseError(response);
  }

  // ─── Modifier une annonce ──────────────────────────────────────────────────

  Future<Ad> updateAd({
    required String adId,
    required String title,
    required String description,
    required double price,
    required String category,
    required String city,
    required String adType,
    bool isNegotiable = false,
    bool isUrgent = false,
    String? whatsappNumber,
    String? address,
    String? expiresAt,
    List<File> newImages = const [],
    List<String> keepImageIds = const [],
    int? primaryImageIndex,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${_baseUrl}ads/$adId/update/'),
    );
    request.headers.addAll(_authHeaders);

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['price'] = price.toStringAsFixed(0);
    request.fields['category'] = category;
    request.fields['city'] = city;
    request.fields['ad_type'] = adType;
    request.fields['is_negotiable'] = isNegotiable.toString();
    request.fields['is_urgent'] = isUrgent.toString();
    if (whatsappNumber != null && whatsappNumber.isNotEmpty) {
      request.fields['whatsapp_number'] = whatsappNumber;
    }
    if (address != null && address.isNotEmpty) {
      request.fields['address'] = address;
    }
    if (expiresAt != null && expiresAt.isNotEmpty) {
      request.fields['expires_at'] = expiresAt;
    }
    if (keepImageIds.isNotEmpty) {
      request.fields['keep_image_ids'] = keepImageIds.join(',');
    }
    for (final img in newImages) {
      request.files.add(await http.MultipartFile.fromPath('images', img.path));
    }
    if (primaryImageIndex != null) {
      request.fields['primary_image_index'] = primaryImageIndex.toString();
    }

    final streamed = await request.send().timeout(AppConfig.connectTimeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return Ad.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    }
    throw _parseError(response);
  }

  // ─── Suppression ───────────────────────────────────────────────────────────

  Future<void> deleteAd(String adId) async {
    final response = await http
        .delete(Uri.parse('${_baseUrl}ads/$adId/delete/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw _parseError(response);
    }
  }

  // ─── Vérification limite d'annonces ───────────────────────────────────────

  Future<Map<String, dynamic>> checkAdLimit() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}ads/check-limit/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {}
    return {'can_post': true, 'remaining': 999};
  }

  // ─── Catégories ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}categories/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final list = data['categories'] ?? data;
        return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return const [
      {'value': 'vehicules', 'label': 'Véhicules'},
      {'value': 'emploi_stages', 'label': 'Emploi & Stages'},
      {'value': 'immobilier', 'label': 'Immobilier'},
      {'value': 'electronique', 'label': 'Électronique'},
      {'value': 'maison_jardin', 'label': 'Maison & Jardin'},
      {'value': 'mode_beaute', 'label': 'Mode & Beauté'},
      {'value': 'sport_loisirs', 'label': 'Sport & Loisirs'},
      {'value': 'services', 'label': 'Services'},
      {'value': 'agroalimentaire', 'label': 'Agroalimentaire'},
      {'value': 'animaux', 'label': 'Animaux'},
      {'value': 'autres', 'label': 'Autres'},
    ];
  }

  // ─── Villes ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCities() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}cities/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final list = data['cities'] ?? data;
        return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return const [
      {'value': 'abidjan', 'label': 'Abidjan'},
      {'value': 'bouake', 'label': 'Bouaké'},
      {'value': 'daloa', 'label': 'Daloa'},
      {'value': 'korhogo', 'label': 'Korhogo'},
      {'value': 'yamoussoukro', 'label': 'Yamoussoukro'},
      {'value': 'man', 'label': 'Man'},
      {'value': 'gagnoa', 'label': 'Gagnoa'},
      {'value': 'san_pedro', 'label': 'San-Pédro'},
      {'value': 'divo', 'label': 'Divo'},
      {'value': 'abengourou', 'label': 'Abengourou'},
    ];
  }

  // ─── Types d'annonces (statique) ───────────────────────────────────────────

  List<Map<String, dynamic>> getAdTypes() {
    return const [
      {'value': 'sell', 'label': 'Vente'},
      {'value': 'rent', 'label': 'Location'},
      {'value': 'service', 'label': 'Service'},
      {'value': 'donation', 'label': 'Don'},
      {'value': 'exchange', 'label': 'Échange'},
    ];
  }

  // ─── Helper erreurs ────────────────────────────────────────────────────────

  Exception _parseError(http.Response response) {
    try {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is Map) {
        if (data['detail'] != null) return Exception(data['detail']);
        if (data['message'] != null) return Exception(data['message']);
        final errors = <String>[];
        data.forEach((key, value) {
          if (value is List)
            errors.addAll(value.map((e) => e.toString()));
          else if (value is String)
            errors.add(value);
        });
        if (errors.isNotEmpty) return Exception(errors.join('. '));
      }
    } catch (_) {}
    switch (response.statusCode) {
      case 400:
        return Exception('Données invalides. Vérifiez vos informations.');
      case 401:
        return Exception('Session expirée. Veuillez vous reconnecter.');
      case 403:
        return Exception('Accès non autorisé.');
      case 404:
        return Exception('Annonce introuvable.');
      case 500:
        return Exception('Erreur serveur. Réessayez plus tard.');
      default:
        return Exception('Erreur de connexion (${response.statusCode}).');
    }
  }
}
