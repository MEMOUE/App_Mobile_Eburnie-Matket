// lib/screens/auth/register_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_widgets.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onRegisterSuccess;
  final VoidCallback? onGoToLogin;
  final VoidCallback? onGoBack;

  const RegisterScreen({
    super.key,
    this.onRegisterSuccess,
    this.onGoToLogin,
    this.onGoBack,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  bool _loading = false;
  String _errorMessage = '';
  String _successMessage = '';
  File? _selectedAvatar;

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
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      final file = File(picked.path);
      final size = await file.length();
      if (size > 1024 * 1024) {
        setState(() => _errorMessage = 'La photo ne doit pas dépasser 1Mo.');
        return;
      }
      setState(() {
        _selectedAvatar = file;
        _errorMessage = '';
      });
    }
  }

  void _removeAvatar() => setState(() => _selectedAvatar = null);

  String? _validateRequired(String? v, {int min = 2}) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    if (v.length < min) return 'Minimum $min caractères';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(v))
      return 'Adresse email invalide';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    if (v.length < 8) return 'Minimum 8 caractères';
    return null;
  }

  String? _validatePasswordConfirm(String? v) {
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
      _successMessage = '';
    });

    try {
      final result = await AuthService().register(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        password: _passwordCtrl.text,
        passwordConfirm: _passwordConfirmCtrl.text,
        phoneNumber: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        avatar: _selectedAvatar,
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _successMessage = result['message'] ?? 'Compte créé avec succès !';
        });
        await Future.delayed(const Duration(seconds: 2));
        widget.onRegisterSuccess?.call();
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

  void _handleBack() {
    if (widget.onGoBack != null) {
      widget.onGoBack!();
    } else if (widget.onGoToLogin != null) {
      widget.onGoToLogin!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppTheme.gray700,
              size: 20,
            ),
            onPressed: _handleBack,
            tooltip: 'Retour',
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    // ── Header ───────────────────────────────────────────────
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
                        Icons.person_add_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Créer un compte',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Rejoignez Éburnie-Market et commencez\nà vendre ou acheter dès maintenant',
                      style: TextStyle(fontSize: 14, color: AppTheme.gray500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // ── Formulaire ───────────────────────────────────────────
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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

                            // Avatar
                            _buildAvatarSection(),
                            const SizedBox(height: 20),

                            _buildField(
                              label: 'Nom d\'utilisateur *',
                              controller: _usernameCtrl,
                              placeholder: 'Choisissez un nom d\'utilisateur',
                              icon: Icons.alternate_email,
                              validator: (v) => _validateRequired(v, min: 3),
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              label: 'Adresse email *',
                              controller: _emailCtrl,
                              placeholder: 'votre@email.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              label: 'Téléphone (optionnel)',
                              controller: _phoneCtrl,
                              placeholder: '+225 07 08 44 09 19',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Vous pourrez l\'ajouter plus tard dans votre profil',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.gray400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildField(
                                    label: 'Prénom *',
                                    controller: _firstNameCtrl,
                                    placeholder: 'Votre prénom',
                                    icon: Icons.person_outline,
                                    validator: _validateRequired,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildField(
                                    label: 'Nom *',
                                    controller: _lastNameCtrl,
                                    placeholder: 'Votre nom',
                                    validator: _validateRequired,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildLabel('Mot de passe *'),
                            const SizedBox(height: 8),
                            _PasswordFormField(
                              controller: _passwordCtrl,
                              placeholder: 'Minimum 8 caractères',
                              validator: _validatePassword,
                              showStrength: true,
                            ),
                            const SizedBox(height: 16),
                            _buildLabel('Confirmer le mot de passe *'),
                            const SizedBox(height: 8),
                            _PasswordFormField(
                              controller: _passwordConfirmCtrl,
                              placeholder: 'Confirmez votre mot de passe',
                              validator: _validatePasswordConfirm,
                            ),
                            const SizedBox(height: 20),

                            // CGU
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrangeLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.primaryOrangeAccent,
                                ),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.gray600,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text:
                                          'En créant un compte, vous acceptez nos ',
                                    ),
                                    TextSpan(
                                      text: 'Conditions d\'utilisation',
                                      style: const TextStyle(
                                        color: AppTheme.primaryOrange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(text: ' et notre '),
                                    TextSpan(
                                      text: 'Politique de confidentialité',
                                      style: const TextStyle(
                                        color: AppTheme.primaryOrange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            PrimaryButton(
                              label: 'Créer mon compte',
                              icon: Icons.person_add_outlined,
                              onPressed: _onSubmit,
                              loading: _loading,
                              loadingLabel: 'Création en cours...',
                            ),

                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Vous avez déjà un compte ?',
                                  style: TextStyle(
                                    color: AppTheme.gray600,
                                    fontSize: 14,
                                  ),
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
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Google ───────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const OrDivider(text: 'Ou continuez avec'),
                          const SizedBox(height: 16),
                          GoogleButton(
                            label: 'Continuer avec Google',
                            onPressed: () => setState(
                              () => _errorMessage =
                                  'L\'inscription Google sera bientôt disponible.',
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildAvatarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Photo de profil (optionnel)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray700,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Max 1Mo',
              style: TextStyle(fontSize: 12, color: AppTheme.gray400),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.gray200,
                  backgroundImage: _selectedAvatar != null
                      ? FileImage(_selectedAvatar!)
                      : null,
                  child: _selectedAvatar == null
                      ? const Icon(
                          Icons.person,
                          size: 36,
                          color: AppTheme.gray400,
                        )
                      : null,
                ),
                if (_selectedAvatar != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: GestureDetector(
                      onTap: _removeAvatar,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppTheme.errorRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.upload_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Choisir une photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Formats acceptés : JPG, JPEG, PNG, GIF',
          style: TextStyle(fontSize: 12, color: AppTheme.gray400),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppTheme.gray700,
    ),
  );

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: AppTheme.gray900, fontSize: 15),
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: icon != null
                ? Icon(icon, color: AppTheme.gray400, size: 20)
                : null,
          ),
        ),
      ],
    );
  }
}

// ─── PasswordFormField avec indicateur de force ───────────────────────────────

class _PasswordFormField extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final String? Function(String?)? validator;
  final bool showStrength;

  const _PasswordFormField({
    required this.controller,
    this.placeholder,
    this.validator,
    this.showStrength = false,
  });

  @override
  State<_PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<_PasswordFormField> {
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

  String get _strengthLabel {
    switch (_strength) {
      case 1:
        return 'Faible';
      case 2:
        return 'Moyen';
      case 3:
        return 'Fort';
      case 4:
        return 'Très fort';
      default:
        return '';
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
            children: [
              ...List.generate(
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
              const SizedBox(width: 8),
              Text(
                _strengthLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: _strengthColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
