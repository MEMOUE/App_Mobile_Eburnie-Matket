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

  // iOS  → clientId = iOS client ID (obligatoire pour éviter le crash)
  // Android → clientId = null (lu depuis google-services.json)
  //           serverClientId = Web client ID (nécessaire pour obtenir l'idToken)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: Platform.isIOS ? AppConfig.googleClientIdIos : null,
    serverClientId: Platform.isAndroid ? AppConfig.googleClientId : null,
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

      // 3. Récupération des jetons d'authentification
      final GoogleSignInAuthentication auth = await account.authentication;

      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Impossible d\'obtenir le token Google (ID Token manquant).\n'
          'Vérifiez que le serverClientId (Web) est bien configuré.',
        );
      }

      // 4. Envoi du token au backend Django
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
    } catch (e) {
      print('Erreur complète GoogleAuth: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
