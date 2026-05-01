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

  // ─────────────────────────────────────────────────────────────────────────
  // IMPORTANT :
  //   • clientId       → iOS seulement (identifie l'app iOS auprès de Google)
  //   • serverClientId → TOUJOURS le Web client ID (= GOOGLE_CLIENT_ID Django)
  //                      Sans cela, le idToken est signé pour le mauvais
  //                      "audience" et Django rejette la vérification.
  // ─────────────────────────────────────────────────────────────────────────
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: Platform.isIOS ? AppConfig.googleClientIdIos : null,
    serverClientId: AppConfig.googleClientId, // ← Web client ID, toujours
    scopes: ['email', 'profile'],
  );

  Future<AuthResponse> signInWithGoogle() async {
    try {
      // 1. Déconnexion propre pour forcer le sélecteur de compte
      await _googleSignIn.signOut();

      // 2. Affichage du sélecteur de compte Google
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        throw Exception('Connexion Google annulée.');
      }

      // 3. Vider le cache d'authentification pour forcer un token frais
      //    (évite les idToken expirés mis en cache par le plugin)
      await account.clearAuthCache();

      // 4. Récupération des jetons d'authentification (token frais garanti)
      final GoogleSignInAuthentication auth = await account.authentication;

      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Impossible d\'obtenir le token Google (ID Token manquant).\n'
          'Vérifiez que serverClientId (Web client ID) est bien configuré '
          'dans GoogleSignIn et dans Google Cloud Console.',
        );
      }

      // 5. Envoi du idToken au backend Django pour vérification
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

      // Gestion des erreurs backend
      final data = json.decode(utf8.decode(response.bodyBytes));
      final msg =
          data['detail'] ??
          data['message'] ??
          data['error'] ??
          'Erreur inconnue (${response.statusCode})';
      throw Exception(msg.toString());
    } on SocketException {
      throw Exception('Problème de connexion réseau.');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Erreur inattendue : $e');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
