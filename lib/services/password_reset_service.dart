// lib/services/password_reset_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class PasswordResetService {
  static final PasswordResetService _instance =
      PasswordResetService._internal();
  factory PasswordResetService() => _instance;
  PasswordResetService._internal();

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // POST /api/user/password/reset/request/
  Future<Map<String, dynamic>> requestReset(String email) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiUrl}user/password/reset/request/'),
          headers: _headers,
          body: json.encode({'email': email}),
        )
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final data = json.decode(response.body);
      if (data['email'] != null) {
        final msg = data['email'] is List ? data['email'][0] : data['email'];
        throw Exception(msg);
      }
      throw Exception('Erreur lors de l\'envoi. Réessayez.');
    }
  }

  // POST /api/user/password/reset/verify/
  Future<TokenVerifyResponse> verifyToken(String token) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiUrl}user/password/reset/verify/'),
          headers: _headers,
          body: json.encode({'token': token}),
        )
        .timeout(AppConfig.connectTimeout);

    final data = json.decode(response.body);
    if (response.statusCode == 200) {
      return TokenVerifyResponse.fromJson(data);
    } else {
      return TokenVerifyResponse(
        valid: false,
        error: data['error'] ?? 'Token invalide ou expiré.',
      );
    }
  }

  // POST /api/user/password/reset/confirm/
  Future<Map<String, dynamic>> confirmReset({
    required String token,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiUrl}user/password/reset/confirm/'),
          headers: _headers,
          body: json.encode({
            'token': token,
            'new_password': newPassword,
            'new_password_confirm': newPasswordConfirm,
          }),
        )
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final data = json.decode(response.body);
      if (data['new_password'] != null) {
        final msg = data['new_password'] is List
            ? data['new_password'].join(', ')
            : data['new_password'];
        throw Exception(msg);
      }
      if (data['error'] != null) throw Exception(data['error']);
      throw Exception('Erreur lors de la réinitialisation.');
    }
  }
}

class TokenVerifyResponse {
  final bool valid;
  final String? email;
  final String? error;

  TokenVerifyResponse({required this.valid, this.email, this.error});

  factory TokenVerifyResponse.fromJson(Map<String, dynamic> json) {
    return TokenVerifyResponse(
      valid: json['valid'] ?? false,
      email: json['email'],
      error: json['error'],
    );
  }
}
