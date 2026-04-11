// lib/services/auth_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;
  String? _token;

  User? get currentUser => _currentUser;
  String? get token => _token;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  // ─── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConfig.tokenKey);
    final userJson = prefs.getString(AppConfig.userKey);
    if (userJson != null) {
      try {
        _currentUser = User.fromJson(json.decode(userJson));
      } catch (_) {
        await logout();
      }
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Token $_token',
  };

  // ─── Login ─────────────────────────────────────────────────────────────────

  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiUrl}auth/login/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': username, 'password': password}),
        )
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(json.decode(response.body));
      await _saveSession(authResponse);
      return authResponse;
    } else {
      throw _parseError(response);
    }
  }

  // ─── Register ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    required String passwordConfirm,
    String? phoneNumber,
    File? avatar,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}user/register/');

    if (avatar != null) {
      final request = http.MultipartRequest('POST', uri);
      request.fields['username'] = username;
      request.fields['email'] = email;
      request.fields['first_name'] = firstName;
      request.fields['last_name'] = lastName;
      request.fields['password'] = password;
      request.fields['password_confirm'] = passwordConfirm;
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        request.fields['phone_number'] = phoneNumber;
      }
      request.files.add(
        await http.MultipartFile.fromPath('avatar', avatar.path),
      );
      final streamed = await request.send().timeout(AppConfig.connectTimeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw _parseError(response);
      }
    } else {
      final body = {
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
        'password_confirm': passwordConfirm,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
      };
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw _parseError(response);
      }
    }
  }

  // ─── Get Profile ───────────────────────────────────────────────────────────

  Future<User> getProfile() async {
    final response = await http
        .get(Uri.parse('${AppConfig.apiUrl}user/profile/'), headers: _headers)
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200) {
      final user = User.fromJson(json.decode(response.body));
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.userKey, json.encode(user.toJson()));
      return user;
    } else {
      throw _parseError(response);
    }
  }

  // ─── Update Profile ────────────────────────────────────────────────────────

  Future<User> updateProfile({
    required String email,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    String? location,
    String? bio,
    File? avatar,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}user/profile/');

    if (avatar != null) {
      final request = http.MultipartRequest('PATCH', uri);
      request.headers.addAll({
        if (_token != null) 'Authorization': 'Token $_token',
      });
      request.fields['email'] = email;
      request.fields['first_name'] = firstName;
      request.fields['last_name'] = lastName;
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        request.fields['phone_number'] = phoneNumber;
      if (location != null && location.isNotEmpty)
        request.fields['location'] = location;
      if (bio != null && bio.isNotEmpty) request.fields['bio'] = bio;
      request.files.add(
        await http.MultipartFile.fromPath('avatar', avatar.path),
      );
      final streamed = await request.send().timeout(AppConfig.connectTimeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) return _parseAndCacheUser(response);
      throw _parseError(response);
    } else {
      final body = {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
        if (location != null && location.isNotEmpty) 'location': location,
        if (bio != null && bio.isNotEmpty) 'bio': bio,
      };
      final response = await http
          .patch(uri, headers: _headers, body: json.encode(body))
          .timeout(AppConfig.connectTimeout);
      if (response.statusCode == 200) return _parseAndCacheUser(response);
      throw _parseError(response);
    }
  }

  // ─── Google Auth (legacy — kept for backward compat) ───────────────────────

  Future<AuthResponse> authenticateWithGoogle(String googleToken) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiUrl}auth/google/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'token': googleToken}),
        )
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final authResponse = AuthResponse.fromJson(json.decode(response.body));
      await _saveSession(authResponse);
      return authResponse;
    } else {
      throw _parseError(response);
    }
  }

  // ─── Sauvegarder une session Google reçue de GoogleAuthService ─────────────
  // Utilisé après GoogleAuthService().signInWithGoogle() pour persister
  // le token et l'user sans refaire d'appel réseau.

  Future<void> saveGoogleSession(AuthResponse authResponse) async {
    await _saveSession(authResponse);
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    if (_token != null) {
      try {
        await http
            .post(
              Uri.parse('${AppConfig.apiUrl}auth/logout/'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.tokenKey);
    await prefs.remove(AppConfig.userKey);
  }

  // ─── Helpers privés ────────────────────────────────────────────────────────

  Future<User> _parseAndCacheUser(http.Response response) async {
    final user = User.fromJson(json.decode(response.body));
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.userKey, json.encode(user.toJson()));
    return user;
  }

  Future<void> _saveSession(AuthResponse authResponse) async {
    _token = authResponse.token;
    _currentUser = authResponse.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.tokenKey, authResponse.token);
    await prefs.setString(
      AppConfig.userKey,
      json.encode(authResponse.user.toJson()),
    );
  }

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
        return Exception('Email ou mot de passe incorrect.');
      case 403:
        return Exception('Ce compte est désactivé.');
      case 409:
        return Exception('Ce nom d\'utilisateur ou cet email existe déjà.');
      case 500:
        return Exception('Erreur serveur. Réessayez plus tard.');
      default:
        return Exception(
          'Impossible de se connecter au serveur (${response.statusCode}).',
        );
    }
  }
}
