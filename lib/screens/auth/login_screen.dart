// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onGoToRegister;
  final VoidCallback? onGoToForgotPassword;
  final VoidCallback? onGoBack;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.onGoToRegister,
    this.onGoToForgotPassword,
    this.onGoBack,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _googleLoading = false;
  bool _rememberMe = false;
  String _errorMessage = '';
  String _successMessage = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadRememberedUser();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConfig.rememberedUsernameKey);
    if (saved != null) {
      setState(() {
        _usernameCtrl.text = saved;
        _rememberMe = true;
      });
    }
  }

  String? _validateUsername(String? v) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    if (v.length < 3) return 'Minimum 3 caractères';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    if (v.length < 8) return 'Minimum 8 caractères';
    return null;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    try {
      final response = await AuthService().login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString(
          AppConfig.rememberedUsernameKey,
          _usernameCtrl.text.trim(),
        );
      } else {
        await prefs.remove(AppConfig.rememberedUsernameKey);
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _successMessage = 'Bienvenue ${response.user.fullName} !';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    try {
      final authResponse = await GoogleAuthService().signInWithGoogle();
      // Sauvegarder la session dans AuthService
      await AuthService().saveGoogleSession(authResponse);
      if (mounted) {
        final msg = authResponse.created
            ? 'Compte créé ! Bienvenue ${authResponse.user.fullName} !'
            : 'Bienvenue ${authResponse.user.fullName} !';
        setState(() {
          _googleLoading = false;
          _successMessage = msg;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _googleLoading = false;
          final msg = e.toString().replaceFirst('Exception: ', '');
          // Ne pas afficher l'erreur si l'utilisateur a juste annulé
          if (!msg.toLowerCase().contains('annulée') &&
              !msg.toLowerCase().contains('cancel')) {
            _errorMessage = msg;
          }
        });
      }
    }
  }

  void _handleBack() {
    if (widget.onGoBack != null)
      widget.onGoBack!();
    else if (Navigator.of(context).canPop())
      Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppTheme.gray700,
              size: 20,
            ),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          const Text(
                            'Bienvenue',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.gray900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Connectez-vous pour accéder à votre compte',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppTheme.gray500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Formulaire ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (_successMessage.isNotEmpty) ...[
                              AppMessage(
                                text: _successMessage,
                                type: MessageType.success,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_errorMessage.isNotEmpty) ...[
                              AppMessage(
                                text: _errorMessage,
                                type: MessageType.error,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _UsernameField(
                              controller: _usernameCtrl,
                              validator: _validateUsername,
                            ),
                            const SizedBox(height: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Mot de passe',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.gray700,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: widget.onGoToForgotPassword,
                                      child: const Text(
                                        'Mot de passe oublié ?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.primaryOrange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _PasswordInput(
                                  controller: _passwordCtrl,
                                  placeholder: 'Entrez votre mot de passe',
                                  validator: _validatePassword,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppTheme.primaryOrange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _rememberMe = v ?? false),
                                ),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _rememberMe = !_rememberMe,
                                  ),
                                  child: const Text(
                                    'Se souvenir de moi',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.gray700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: 'Se connecter',
                              icon: Icons.login,
                              onPressed: _onSubmit,
                              loading: _loading,
                              loadingLabel: 'Connexion en cours...',
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Vous n\'avez pas de compte ?',
                                  style: TextStyle(
                                    color: AppTheme.gray600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: widget.onGoToRegister,
                                  child: const Text(
                                    'Créer un compte',
                                    style: TextStyle(
                                      color: AppTheme.primaryOrange,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Connexion Google ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const OrDivider(),
                          const SizedBox(height: 20),
                          GoogleButton(
                            label: 'Continuer avec Google',
                            onPressed: _loginWithGoogle,
                            loading: _googleLoading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _FeatureBadge(
                            icon: Icons.shopping_bag_outlined,
                            color: AppTheme.primaryOrange,
                            label: 'Gérez vos annonces',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FeatureBadge(
                            icon: Icons.favorite_border,
                            color: AppTheme.errorRed,
                            label: 'Sauvegardez vos favoris',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  const _UsernameField({required this.controller, this.validator});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Email ou nom d\'utilisateur',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.gray700,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        validator: validator,
        style: const TextStyle(color: AppTheme.gray900, fontSize: 15),
        decoration: const InputDecoration(
          hintText: 'Entrez votre email ou nom d\'utilisateur',
          prefixIcon: Icon(
            Icons.person_outline,
            color: AppTheme.gray400,
            size: 20,
          ),
        ),
      ),
    ],
  );
}

class _PasswordInput extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final String? Function(String?)? validator;
  const _PasswordInput({
    required this.controller,
    this.placeholder,
    this.validator,
  });

  @override
  State<_PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<_PasswordInput> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscure,
    validator: widget.validator,
    textInputAction: TextInputAction.done,
    style: const TextStyle(color: AppTheme.gray900, fontSize: 15),
    decoration: InputDecoration(
      hintText: widget.placeholder,
      prefixIcon: const Icon(
        Icons.lock_outline,
        color: AppTheme.gray400,
        size: 20,
      ),
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppTheme.gray400,
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
  );
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _FeatureBadge({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
