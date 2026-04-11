// lib/services/google_auth_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: Platform.isIOS ? AppConfig.googleClientIdIos : null,
    scopes: ['email', 'profile'],
  );

  Future<AuthResponse> signInWithGoogle() async {
    try {
      // 1. Déconnexion propre
      await _googleSignIn.signOut();

      // 2. Tentative de connexion
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        throw Exception('Connexion Google annulée.');
      }

      // 3. Récupération des jetons
      final GoogleSignInAuthentication auth = await account.authentication;

      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Impossible d\'obtenir le token Google (ID Token manquant).',
        );
      }

      // 4. Appel Backend
      final response = await http
          .post(
            Uri.parse('${AppConfig.apiUrl}auth/google/'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'token': idToken}),
          )
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse.fromJson(
          json.decode(utf8.decode(response.bodyBytes)),
        );
      }

      final data = json.decode(utf8.decode(response.bodyBytes));
      final msg =
          data['detail'] ??
          data['message'] ??
          data['error'] ??
          'Erreur inconnue';
      throw Exception(msg.toString());
    } on SocketException {
      throw Exception('Problème de connexion réseau.');
    } catch (e) {
      print("Erreur complète GoogleAuth: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
