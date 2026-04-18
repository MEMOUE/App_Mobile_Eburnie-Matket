// lib/services/magasin_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/magasin.dart';
import 'auth_service.dart';

class MagasinService {
  static final MagasinService _instance = MagasinService._internal();
  factory MagasinService() => _instance;
  MagasinService._internal();

  String get _baseUrl => '${AppConfig.apiUrl}magasins_marches/';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (AuthService().token != null)
      'Authorization': 'Token ${AuthService().token}',
  };

  Map<String, String> get _authHeaders => {
    'Accept': 'application/json',
    if (AuthService().token != null)
      'Authorization': 'Token ${AuthService().token}',
  };

  // ─── Référentiel marchés ──────────────────────────────────────────────────

  Future<List<Marche>> getMarches({String? ville}) async {
    try {
      final uri = Uri.parse(
        '${_baseUrl}marches/',
      ).replace(queryParameters: ville != null ? {'ville': ville} : null);
      final response = await http
          .get(uri, headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final list = data['marches'] ?? data;
        return (list as List).map((e) => Marche.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── Marchés groupés par ville ────────────────────────────────────────────
  //
  // Essaie d'abord l'endpoint /marches/grouped/ du backend.
  // En cas d'échec, reconstruit le groupement côté client à partir de getMarches().

  Future<List<MarcheGroup>> getMarchesGrouped() async {
    // Tentative via endpoint dédié
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}marches/grouped/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final list = data['grouped'] ?? data;
        if (list is List && list.isNotEmpty) {
          return list.map((e) => MarcheGroup.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    // Fallback : groupement client-side
    final marches = await getMarches();
    if (marches.isEmpty) return [];

    final Map<String, MarcheGroup> grouped = {};
    for (final m in marches) {
      if (!grouped.containsKey(m.villeCode)) {
        grouped[m.villeCode] = MarcheGroup(
          ville: m.villeCode,
          villeLabel: m.villeLabel.isNotEmpty ? m.villeLabel : m.villeCode,
          marches: [],
        );
      }
      grouped[m.villeCode]!.marches.add(m);
    }

    // Garder seulement les villes avec ≥ 2 marchés (comme Angular)
    return grouped.values.where((g) => g.marches.length >= 2).toList();
  }

  // ─── Liste publique ───────────────────────────────────────────────────────

  Future<List<Magasin>> getMagasins({
    String? ville,
    String? categorie,
    String? marche,
    String? search,
    bool verifiedOnly = false,
  }) async {
    final params = <String, String>{};
    if (ville != null && ville.isNotEmpty) params['ville'] = ville;
    if (categorie != null && categorie.isNotEmpty)
      params['categorie'] = categorie;
    if (marche != null && marche.isNotEmpty) params['marche'] = marche;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (verifiedOnly) params['verified'] = 'true';

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(AppConfig.connectTimeout);
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final list = data is List ? data : (data['results'] ?? data);
      return (list as List).map((e) => Magasin.fromJson(e)).toList();
    }
    throw _parseError(response);
  }

  // ─── Détail ───────────────────────────────────────────────────────────────

  Future<Magasin> getMagasin(int id) async {
    final response = await http
        .get(Uri.parse('$_baseUrl$id/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);
    if (response.statusCode == 200) {
      return Magasin.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    }
    throw _parseError(response);
  }

  // ─── Annonces du magasin ──────────────────────────────────────────────────

  Future<List<dynamic>> getMagasinAnnonces(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl$id/annonces/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['annonces'] ?? (data is List ? data : []);
      }
    } catch (_) {}
    return [];
  }

  // ─── Mes magasins ─────────────────────────────────────────────────────────

  Future<List<Magasin>> getMyMagasins() async {
    final response = await http
        .get(Uri.parse('${_baseUrl}my/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final list = data is List ? data : (data['results'] ?? data);
      return (list as List).map((e) => Magasin.fromJson(e)).toList();
    }
    throw _parseError(response);
  }

  // ─── Sélecteur léger ─────────────────────────────────────────────────────

  Future<List<MagasinSelector>> getMyMagasinsSelector() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}my/selector/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final list = data['magasins'] ?? (data is List ? data : []);
        return (list as List).map((e) => MagasinSelector.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── Créer un magasin ─────────────────────────────────────────────────────

  Future<Magasin> createMagasin({
    required String nom,
    String? description,
    required String categorie,
    required String ville,
    String? marche,
    String? numeroStand,
    String? adresse,
    double? latitude,
    double? longitude,
    String? telephone,
    String? whatsapp,
    String? emailContact,
    bool isActive = true,
    File? logo,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}create/'),
    );
    request.headers.addAll(_authHeaders);
    _fillFields(
      request,
      nom,
      description,
      categorie,
      ville,
      marche,
      numeroStand,
      adresse,
      latitude,
      longitude,
      telephone,
      whatsapp,
      emailContact,
      isActive,
    );
    if (logo != null) {
      request.files.add(await http.MultipartFile.fromPath('logo', logo.path));
    }
    return _sendAndParse(request, 201);
  }

  // ─── Modifier un magasin ──────────────────────────────────────────────────

  Future<Magasin> updateMagasin({
    required int id,
    required String nom,
    String? description,
    required String categorie,
    required String ville,
    String? marche,
    String? numeroStand,
    String? adresse,
    double? latitude,
    double? longitude,
    String? telephone,
    String? whatsapp,
    String? emailContact,
    bool isActive = true,
    File? logo,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl$id/update/'),
    );
    request.headers.addAll(_authHeaders);
    _fillFields(
      request,
      nom,
      description,
      categorie,
      ville,
      marche,
      numeroStand,
      adresse,
      latitude,
      longitude,
      telephone,
      whatsapp,
      emailContact,
      isActive,
    );
    if (logo != null) {
      request.files.add(await http.MultipartFile.fromPath('logo', logo.path));
    }
    return _sendAndParse(request, 200);
  }

  // ─── Supprimer ────────────────────────────────────────────────────────────

  Future<void> deleteMagasin(int id) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl$id/delete/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw _parseError(response);
    }
  }

  // ─── Helpers privés ───────────────────────────────────────────────────────

  void _fillFields(
    http.MultipartRequest request,
    String nom,
    String? description,
    String categorie,
    String ville,
    String? marche,
    String? numeroStand,
    String? adresse,
    double? latitude,
    double? longitude,
    String? telephone,
    String? whatsapp,
    String? emailContact,
    bool isActive,
  ) {
    request.fields['nom'] = nom;
    request.fields['categorie'] = categorie;
    request.fields['ville'] = ville;
    request.fields['is_active'] = isActive.toString();
    if (description != null && description.isNotEmpty)
      request.fields['description'] = description;
    if (marche != null && marche.isNotEmpty) request.fields['marche'] = marche;
    if (numeroStand != null && numeroStand.isNotEmpty)
      request.fields['numero_stand'] = numeroStand;
    if (adresse != null && adresse.isNotEmpty)
      request.fields['adresse'] = adresse;
    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();
    if (telephone != null && telephone.isNotEmpty)
      request.fields['telephone'] = telephone;
    if (whatsapp != null && whatsapp.isNotEmpty)
      request.fields['whatsapp'] = whatsapp;
    if (emailContact != null && emailContact.isNotEmpty)
      request.fields['email_contact'] = emailContact;
  }

  Future<Magasin> _sendAndParse(
    http.MultipartRequest request,
    int expectedCode,
  ) async {
    final streamed = await request.send().timeout(AppConfig.connectTimeout);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == expectedCode || response.statusCode == 200) {
      return Magasin.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    }
    throw _parseError(response);
  }

  Exception _parseError(http.Response response) {
    try {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is Map) {
        if (data['detail'] != null) return Exception(data['detail']);
        if (data['message'] != null) return Exception(data['message']);
        final errors = <String>[];
        data.forEach((k, v) {
          if (v is List) errors.addAll(v.map((e) => e.toString()));
          if (v is String) errors.add(v);
        });
        if (errors.isNotEmpty) return Exception(errors.join('. '));
      }
    } catch (_) {}
    switch (response.statusCode) {
      case 400:
        return Exception('Données invalides.');
      case 401:
        return Exception('Session expirée. Reconnectez-vous.');
      case 403:
        return Exception('Accès non autorisé.');
      case 404:
        return Exception('Magasin introuvable.');
      case 500:
        return Exception('Erreur serveur. Réessayez plus tard.');
      default:
        return Exception('Erreur réseau (${response.statusCode}).');
    }
  }
}
