// lib/config/app_config.dart

class AppConfig {
  // URLs API
  static const String apiUrl = 'http://192.168.1.12:8000/api/';
  static const String mediaUrl = 'http://192.168.1.12:8000';
  static const String frontendUrl = 'http://192.168.1.12:4200';
  // Google OAuth
  static const String googleClientId =
      '335632105023-hvpq1kbtmmf0uf1ga5126uf5e3iabvul.apps.googleusercontent.com';

  // App
  static const String appName = 'Éburnie-Market';
  static const String appVersion = '1.0.0';

  // Token keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';
  static const String rememberedUsernameKey = 'remembered_username';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
