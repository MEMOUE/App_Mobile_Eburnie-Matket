// lib/screens/auth/forgot_password_screen.dart

import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/password_reset_service.dart';
import '../../widgets/app_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback? onGoToLogin;

  const ForgotPasswordScreen({super.key, this.onGoToLogin});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _emailSent = false;
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
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    final emailReg = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!emailReg.hasMatch(v)) return 'Adresse email invalide';
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
      final result = await PasswordResetService().requestReset(
        _emailCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _emailSent = true;
          _successMessage = result['message'] ?? 'Email envoyé avec succès !';
        });

        // Redirection automatique après 5s vers login
        Future.delayed(const Duration(seconds: 5), () {
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

  void _resetForm() {
    setState(() {
      _emailSent = false;
      _successMessage = '';
      _errorMessage = '';
      _emailCtrl.clear();
    });
    _animController.reset();
    _animController.forward();
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
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    Center(
                      child: Text(
                        'Mot de passe oublié ?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gray900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Card principale ──────────────────────────────────────
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
                      child: _emailSent
                          ? _buildSuccessContent()
                          : _buildFormContent(),
                    ),

                    const SizedBox(height: 24),

                    // ── Infos sécurité ───────────────────────────────────────
                    const SecurityInfoCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Vue succès (email envoyé) ─────────────────────────────────────────────

  Widget _buildSuccessContent() {
    return Column(
      children: [
        // Icône succès animée
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
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

        // Info boîte de réception
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.infoBlueLight,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: AppTheme.infoBlue, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Vérifiez votre boîte de réception',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.gray700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Si un compte existe avec cet email, vous recevrez un lien de réinitialisation dans quelques instants.',
                style: TextStyle(fontSize: 13, color: AppTheme.gray600),
              ),
              SizedBox(height: 6),
              Text(
                'N\'oubliez pas de vérifier vos spams si vous ne voyez pas l\'email.',
                style: TextStyle(fontSize: 13, color: AppTheme.gray600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        PrimaryButton(
          label: 'Retour à la connexion',
          icon: Icons.login,
          onPressed: widget.onGoToLogin,
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: 'Renvoyer un email',
          icon: Icons.refresh,
          onPressed: _resetForm,
        ),
      ],
    );
  }

  // ── Formulaire de demande ─────────────────────────────────────────────────

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage.isNotEmpty) ...[
            AppMessage(text: _errorMessage, type: MessageType.error),
            const SizedBox(height: 16),
          ],

          const Text(
            'Adresse email',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _onSubmit(),
            style: const TextStyle(color: AppTheme.gray900, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'votre@email.com',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: AppTheme.gray400,
                size: 20,
              ),
            ),
          ),

          const SizedBox(height: 24),

          PrimaryButton(
            label: 'Envoyer le lien',
            icon: Icons.send_outlined,
            onPressed: _onSubmit,
            loading: _loading,
            loadingLabel: 'Envoi en cours...',
          ),

          const SizedBox(height: 20),

          const Divider(color: AppTheme.gray200, thickness: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Vous vous souvenez de votre mot de passe ?',
                style: TextStyle(color: AppTheme.gray600, fontSize: 14),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onGoToLogin,
                child: const Text(
                  'Se connecter',
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
    );
  }
}
