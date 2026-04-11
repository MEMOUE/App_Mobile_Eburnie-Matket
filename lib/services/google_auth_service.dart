// lib/services/google_auth_service.dart

import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: AppConfig.googleClientId,
    scopes: ['email', 'profile'],
  );

  /// Connexion Google → retourne AuthResponse (token + user)
  /// Lance une Exception en cas d'échec
  Future<AuthResponse> signInWithGoogle() async {
    // Déconnecter une session précédente pour forcer le sélecteur de compte
    await _googleSignIn.signOut();

    final GoogleSignInAccount? account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Connexion Google annulée.');
    }

    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Impossible d\'obtenir le token Google.');
    }

    // Envoyer le token au backend Django
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

    // Extraire le message d'erreur du backend
    try {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final msg = data['detail'] ?? data['message'] ?? data['error'];
      if (msg != null) throw Exception(msg.toString());
    } catch (e) {
      if (e is Exception) rethrow;
    }
    throw Exception(
      'Erreur d\'authentification Google (${response.statusCode}).',
    );
  }

  /// Déconnexion Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
