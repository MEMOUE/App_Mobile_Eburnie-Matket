// lib/screens/auth/reset_password_screen.dart

import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/password_reset_service.dart';
import '../../widgets/app_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  final VoidCallback? onGoToLogin;
  final VoidCallback? onGoToForgotPassword;

  const ResetPasswordScreen({
    super.key,
    required this.token,
    this.onGoToLogin,
    this.onGoToForgotPassword,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  bool _loading = false;
  bool _verifying = true;
  bool _tokenValid = false;
  bool _passwordReset = false;
  String _errorMessage = '';
  String _successMessage = '';
  String _userEmail = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

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
    _animController.forward();
    _verifyToken();
  }

  @override
  void dispose() {
    _animController.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyToken() async {
    if (widget.token.isEmpty) {
      setState(() {
        _verifying = false;
        _tokenValid = false;
        _errorMessage = 'Aucun token de réinitialisation fourni.';
      });
      return;
    }

    try {
      final result = await PasswordResetService().verifyToken(widget.token);
      if (mounted) {
        setState(() {
          _verifying = false;
          _tokenValid = result.valid;
          _userEmail = result.email ?? '';
          if (!result.valid) {
            _errorMessage = result.error ?? 'Token invalide ou expiré.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _tokenValid = false;
          _errorMessage = 'Impossible de vérifier le token.';
        });
      }
    }
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    if (v.length < 8) return 'Minimum 8 caractères';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    if (v != _passwordCtrl.text)
      return 'Les mots de passe ne correspondent pas';
    return null;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    try {
      final result = await PasswordResetService().confirmReset(
        token: widget.token,
        newPassword: _passwordCtrl.text,
        newPasswordConfirm: _passwordConfirmCtrl.text,
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _passwordReset = true;
          _successMessage = result['message'] ?? 'Mot de passe réinitialisé !';
        });

        // Redirection auto après 3s
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) widget.onGoToLogin?.call();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
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
            icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.gray700),
            onPressed: widget.onGoToLogin,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── Header ─────────────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryOrange.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Réinitialiser le mot de passe',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.gray900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Créez un nouveau mot de passe sécurisé',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.gray500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Card principale ───────────────────────────────────────
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
                    child: _buildContent(),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Vérification en cours
    if (_verifying) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppTheme.primaryOrange),
            SizedBox(height: 16),
            Text(
              'Vérification du lien en cours...',
              style: TextStyle(color: AppTheme.gray600, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Token invalide
    if (!_tokenValid) {
      return Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.errorRedLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppTheme.errorRedDark,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppMessage(text: _errorMessage, type: MessageType.error),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Demander un nouveau lien',
            icon: Icons.refresh,
            onPressed: widget.onGoToForgotPassword,
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Retour à la connexion',
            icon: Icons.login,
            onPressed: widget.onGoToLogin,
          ),
        ],
      );
    }

    // Succès
    if (_passwordReset) {
      return Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successGreenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppTheme.successGreenDark,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppMessage(text: _successMessage, type: MessageType.success),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.infoBlueLight,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: AppTheme.infoBlue, width: 4),
              ),
            ),
            child: const Text(
              'Redirection automatique vers la page de connexion dans quelques instants...',
              style: TextStyle(fontSize: 13, color: AppTheme.gray600),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Se connecter maintenant',
            icon: Icons.login,
            onPressed: widget.onGoToLogin,
          ),
        ],
      );
    }

    // Formulaire
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage.isNotEmpty) ...[
            AppMessage(text: _errorMessage, type: MessageType.error),
            const SizedBox(height: 16),
          ],

          // Email de l'utilisateur
          if (_userEmail.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBlueLight,
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: AppTheme.infoBlue, width: 4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    color: AppTheme.infoBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Compte : $_userEmail',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Nouveau mot de passe
          const Text(
            'Nouveau mot de passe *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 8),
          _ResetPasswordField(
            controller: _passwordCtrl,
            placeholder: 'Minimum 8 caractères',
            validator: _validatePassword,
            showStrength: true,
          ),

          const SizedBox(height: 16),

          // Confirmation
          const Text(
            'Confirmer le mot de passe *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 8),
          _ResetPasswordField(
            controller: _passwordConfirmCtrl,
            placeholder: 'Confirmez votre mot de passe',
            validator: _validateConfirm,
          ),

          const SizedBox(height: 20),

          // Conseils sécurité
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrangeLight,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: AppTheme.primaryOrange, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conseils pour un mot de passe sécurisé :',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final tip in [
                  'Au moins 8 caractères',
                  'Mélangez majuscules et minuscules',
                  'Incluez des chiffres et des caractères spéciaux',
                  'Évitez les mots du dictionnaire',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $tip',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.gray600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          PrimaryButton(
            label: 'Réinitialiser le mot de passe',
            icon: Icons.check_outlined,
            onPressed: _onSubmit,
            loading: _loading,
            loadingLabel: 'Réinitialisation...',
          ),

          const SizedBox(height: 20),

          const Divider(color: AppTheme.gray200),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Vous vous souvenez de votre mot de passe ?',
                style: TextStyle(color: AppTheme.gray600, fontSize: 13),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onGoToLogin,
                child: const Text(
                  'Se connecter',
                  style: TextStyle(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── ResetPasswordField ───────────────────────────────────────────────────────

class _ResetPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final String? Function(String?)? validator;
  final bool showStrength;

  const _ResetPasswordField({
    required this.controller,
    this.placeholder,
    this.validator,
    this.showStrength = false,
  });

  @override
  State<_ResetPasswordField> createState() => _ResetPasswordFieldState();
}

class _ResetPasswordFieldState extends State<_ResetPasswordField> {
  bool _obscure = true;

  int get _strength {
    final v = widget.controller.text;
    if (v.length < 8) return 0;
    int s = 1;
    if (RegExp(r'[A-Z]').hasMatch(v)) s++;
    if (RegExp(r'[0-9]').hasMatch(v)) s++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(v)) s++;
    return s;
  }

  Color get _strengthColor {
    switch (_strength) {
      case 1:
        return AppTheme.errorRed;
      case 2:
        return const Color(0xFFF97316);
      case 3:
        return const Color(0xFFEAB308);
      case 4:
        return AppTheme.successGreen;
      default:
        return AppTheme.gray200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          validator: widget.validator,
          textInputAction: TextInputAction.next,
          onChanged: widget.showStrength ? (_) => setState(() {}) : null,
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
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.gray400,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (widget.showStrength && widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i < _strength ? _strengthColor : AppTheme.gray200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
