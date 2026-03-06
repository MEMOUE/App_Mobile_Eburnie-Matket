// lib/services/annonce_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/annonce.dart';
import 'auth_service.dart';

class AnnonceService {
  static final AnnonceService _instance = AnnonceService._internal();
  factory AnnonceService() => _instance;
  AnnonceService._internal();

  String get _baseUrl => '${AppConfig.apiUrl}produit/';

  /// Headers HTTP : toujours JSON + token si connecté
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (AuthService().token != null)
      'Authorization': 'Token ${AuthService().token}',
  };

  // ─── Page d'accueil ────────────────────────────────────────────────────────

  /// Récupère les données de la page d'accueil (vedettes, urgentes, récentes)
  Future<HomeData> getHomeData() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}home-data/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return HomeData.fromJson(data);
      }
      throw _parseError(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Impossible de charger la page d\'accueil');
    }
  }

  // ─── Liste des annonces ────────────────────────────────────────────────────

  /// Récupère les annonces avec filtres optionnels
  Future<AdsResponse> getAds({
    String? category,
    String? city,
    String? search,
    double? priceMin,
    double? priceMax,
    String ordering = '-created_at',
    int page = 1,
  }) async {
    final params = <String, String>{};
    if (category != null && category.isNotEmpty) params['category'] = category;
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
      final data = json.decode(utf8.decode(response.bodyBytes));
      return AdsResponse.fromJson(data);
    }
    throw _parseError(response);
  }

  // ─── Détail d'une annonce ──────────────────────────────────────────────────

  /// Récupère les détails complets d'une annonce
  Future<Ad> getAdDetail(String adId) async {
    final response = await http
        .get(Uri.parse('${_baseUrl}ads/$adId/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return Ad.fromJson(data);
    }
    throw _parseError(response);
  }

  // ─── Mes annonces ──────────────────────────────────────────────────────────

  /// Récupère les annonces de l'utilisateur connecté
  Future<List<Ad>> getMyAds() async {
    final response = await http
        .get(Uri.parse('${_baseUrl}my-ads/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is List) {
        return data.map((e) => Ad.fromJson(e)).toList();
      }
      if (data is Map && data['results'] != null) {
        return (data['results'] as List).map((e) => Ad.fromJson(e)).toList();
      }
      return [];
    }
    throw _parseError(response);
  }

  // ─── Suppression ───────────────────────────────────────────────────────────

  /// Supprime une annonce
  Future<void> deleteAd(String adId) async {
    final response = await http
        .delete(Uri.parse('${_baseUrl}ads/$adId/delete/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw _parseError(response);
    }
  }

  // ─── Catégories & Villes ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await http
        .get(Uri.parse('${_baseUrl}categories/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final list = data['categories'] ?? data;
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getCities() async {
    final response = await http
        .get(Uri.parse('${_baseUrl}cities/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final list = data['cities'] ?? data;
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  // ─── Helper erreurs ────────────────────────────────────────────────────────

  Exception _parseError(http.Response response) {
    try {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is Map) {
        if (data['detail'] != null) return Exception(data['detail']);
        if (data['message'] != null) return Exception(data['message']);
      }
    } catch (_) {}

    switch (response.statusCode) {
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
