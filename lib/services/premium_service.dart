// lib/services/premium_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/premium.dart';
import 'auth_service.dart';

class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  String get _baseUrl => '${AppConfig.apiUrl}premium/';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (AuthService().token != null)
      'Authorization': 'Token ${AuthService().token}',
  };

  // ── Plans disponibles ─────────────────────────────────────────────────────

  Future<List<PremiumPlan>> getPlans() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}plans/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final list = data is List ? data : (data['results'] ?? data);
        return (list as List).map((e) => PremiumPlan.fromJson(e)).toList();
      }
      throw _parseError(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur chargement des plans: $e');
    }
  }

  // ── Souscrire à un plan ───────────────────────────────────────────────────

  Future<SubscribeResponse> subscribe({
    required int planId,
    required String paymentMethod, // 'wave' | 'orange_money' | 'mtn_money'
    required String phoneNumber,
  }) async {
    final response = await http
        .post(
          Uri.parse('${_baseUrl}subscribe/'),
          headers: _headers,
          body: json.encode({
            'plan_id': planId,
            'payment_method': paymentMethod,
            'phone_number': phoneNumber,
          }),
        )
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return SubscribeResponse.fromJson(
        json.decode(utf8.decode(response.bodyBytes)),
      );
    }
    throw _parseError(response);
  }

  // ── Mes abonnements ───────────────────────────────────────────────────────

  Future<List<PremiumSubscription>> getMySubscriptions() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}my-subscriptions/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final list = data is List ? data : (data['results'] ?? data);
        return (list as List)
            .map((e) => PremiumSubscription.fromJson(e))
            .toList();
      }
      throw _parseError(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur chargement abonnements: $e');
    }
  }

  // ── Statut premium ────────────────────────────────────────────────────────

  Future<PremiumStatus> checkStatus() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}check-status/'), headers: _headers)
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode == 200) {
        return PremiumStatus.fromJson(
          json.decode(utf8.decode(response.bodyBytes)),
        );
      }
      throw _parseError(response);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur vérification statut: $e');
    }
  }

  // ── Annuler un abonnement ─────────────────────────────────────────────────

  Future<void> cancelSubscription(int subscriptionId) async {
    final response = await http
        .post(
          Uri.parse('${_baseUrl}subscriptions/$subscriptionId/cancel/'),
          headers: _headers,
        )
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _parseError(response);
    }
  }

  // ── Helper erreurs ────────────────────────────────────────────────────────

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
      case 500:
        return Exception('Erreur serveur. Réessayez plus tard.');
      default:
        return Exception('Erreur réseau (${response.statusCode}).');
    }
  }
}
