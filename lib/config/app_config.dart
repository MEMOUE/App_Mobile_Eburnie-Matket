// lib/config/app_config.dart

class AppConfig {
  // URLs API
  static const String apiUrl = 'https://www.eburnie-market.com/api/';
  static const String mediaUrl = 'https://www.eburnie-market.com';
  static const String frontendUrl = 'https://www.eburnie-market.com';

  // Google OAuth — client ID Web (pour serverClientId Android + backend Django)
  static const String googleClientId =
      '335632105023-hvpq1kbtmmf0uf1ga5126uf5e3iabvul.apps.googleusercontent.com';

  // Google OAuth — client ID iOS
  static const String googleClientIdIos =
      '335632105023-o9bd3gekvjk2qcqkrd62vlimqoartoc8.apps.googleusercontent.com';

  // Google OAuth — client ID Android
  static const String googleClientIdAndroid =
      '335632105023-6t3l43g7lc2pujs4kkuda53gmseqh8rn.apps.googleusercontent.com';

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
