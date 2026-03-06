// lib/screens/auth/profile_edit_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_widgets.dart';

class ProfileEditScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;
  final VoidCallback? onGoToChangePassword;

  const ProfileEditScreen({
    super.key,
    this.onSaved,
    this.onCancel,
    this.onGoToChangePassword,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _loading = false;
  String _errorMessage = '';
  String _successMessage = '';
  File? _selectedAvatar;
  String? _existingAvatarUrl;
  User? _currentUser;

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
    _loadUser();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _locationCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _loadUser() {
    final user = AuthService().currentUser;
    if (user != null) {
      _fillForm(user);
    } else {
      AuthService().getProfile().then(_fillForm).catchError((_) {
        if (mounted) {
          setState(() => _errorMessage = 'Impossible de charger votre profil.');
        }
      });
    }
  }

  void _fillForm(User user) {
    if (!mounted) return;
    setState(() {
      _currentUser = user;
      _emailCtrl.text = user.email;
      _phoneCtrl.text = user.phoneNumber ?? '';
      _firstNameCtrl.text = user.firstName ?? '';
      _lastNameCtrl.text = user.lastName ?? '';
      _locationCtrl.text = user.location ?? '';
      _bioCtrl.text = user.bio ?? '';
      _existingAvatarUrl = user.avatarUrl;
    });
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

  void _removeAvatar() {
    setState(() {
      _selectedAvatar = null;
      _existingAvatarUrl = null;
    });
  }

  String? _validateRequired(String? v, {int min = 2}) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    if (v.length < min) return 'Minimum $min caractères';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Ce champ est requis';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(v)) {
      return 'Adresse email invalide';
    }
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
      await AuthService().updateProfile(
        email: _emailCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        avatar: _selectedAvatar,
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _successMessage = 'Profil mis à jour avec succès !';
        });

        await Future.delayed(const Duration(seconds: 2));
        widget.onSaved?.call();
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
            onPressed: widget.onCancel,
          ),
          title: const Text(
            'Modifier mon profil',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray900,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
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
                            // Messages
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

                            // ── Avatar ──────────────────────────────────────
                            _buildAvatarSection(),
                            const SizedBox(height: 20),

                            const Divider(color: AppTheme.gray200),
                            const SizedBox(height: 20),

                            // ── Username (lecture seule) ────────────────────
                            _buildReadonlyField(
                              label: 'Nom d\'utilisateur',
                              value: _currentUser?.username ?? '',
                              icon: Icons.alternate_email,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Le nom d\'utilisateur ne peut pas être modifié',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.gray400,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Email ───────────────────────────────────────
                            _buildField(
                              label: 'Adresse email *',
                              controller: _emailCtrl,
                              placeholder: 'votre@email.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 16),

                            // ── Téléphone ───────────────────────────────────
                            _buildField(
                              label: 'Numéro de téléphone (optionnel)',
                              controller: _phoneCtrl,
                              placeholder: '+225 07 08 44 09 19',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),

                            // ── Prénom / Nom ────────────────────────────────
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

                            // ── Localisation ────────────────────────────────
                            _buildField(
                              label: 'Localisation (optionnel)',
                              controller: _locationCtrl,
                              placeholder: 'Ville, Pays',
                              icon: Icons.location_on_outlined,
                            ),
                            const SizedBox(height: 16),

                            // ── Bio ─────────────────────────────────────────
                            _buildField(
                              label: 'Bio (optionnel)',
                              controller: _bioCtrl,
                              placeholder: 'Parlez-nous un peu de vous...',
                              icon: Icons.edit_note,
                              maxLines: 4,
                              maxLength: 500,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Maximum 500 caractères',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.gray400,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Boutons ─────────────────────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: PrimaryButton(
                                    label: 'Enregistrer',
                                    icon: Icons.check_outlined,
                                    onPressed: _onSubmit,
                                    loading: _loading,
                                    loadingLabel: 'Mise à jour...',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SecondaryButton(
                                    label: 'Annuler',
                                    icon: Icons.close,
                                    onPressed: _loading
                                        ? null
                                        : widget.onCancel,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            const Divider(color: AppTheme.gray200),
                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Besoin de changer votre mot de passe ?',
                                  style: TextStyle(
                                    color: AppTheme.gray600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: widget.onGoToChangePassword,
                                  child: const Text(
                                    'Cliquez ici',
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
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Infos compte ──────────────────────────────────────────
                    if (_currentUser != null) _buildAccountInfo(_currentUser!),

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
              'Photo de profil',
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
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.gray200,
                  backgroundImage: _selectedAvatar != null
                      ? FileImage(_selectedAvatar!) as ImageProvider
                      : (_existingAvatarUrl != null
                            ? NetworkImage(_existingAvatarUrl!)
                            : null),
                  child: _selectedAvatar == null && _existingAvatarUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppTheme.gray400,
                        )
                      : null,
                ),
                if (_selectedAvatar != null || _existingAvatarUrl != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: GestureDetector(
                      onTap: _removeAvatar,
                      child: Container(
                        width: 24,
                        height: 24,
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
            // Bouton
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
                child: Row(
                  children: const [
                    Icon(Icons.upload_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Changer la photo',
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

  Widget _buildReadonlyField({
    required String label,
    required String value,
    IconData? icon,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.gray100,
            border: Border.all(color: AppTheme.gray200, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppTheme.gray400, size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                value,
                style: const TextStyle(color: AppTheme.gray500, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLines,
    int? maxLength,
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
          maxLines: maxLines ?? 1,
          maxLength: maxLength,
          textInputAction: maxLines != null && maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.next,
          style: const TextStyle(color: AppTheme.gray900, fontSize: 15),
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: icon != null
                ? Icon(icon, color: AppTheme.gray400, size: 20)
                : null,
            counterText: maxLength != null ? null : '',
          ),
        ),
      ],
    );
  }

  Widget _buildAccountInfo(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: AppTheme.primaryOrange, size: 20),
              SizedBox(width: 8),
              Text(
                'Informations du compte',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              if (user.createdAt != null)
                _infoItem(
                  label: 'Membre depuis',
                  value: _formatDate(user.createdAt!),
                ),
              _infoItemBadge(
                label: 'Email vérifié',
                verified: user.emailVerified,
              ),
              _infoItemBadge(
                label: 'Téléphone vérifié',
                verified: user.phoneVerified,
              ),
              _premiumBadge(user.isPremiumActive),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return date.substring(0, 10);
    }
  }

  Widget _infoItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.gray400),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray700,
          ),
        ),
      ],
    );
  }

  Widget _infoItemBadge({required String label, required bool verified}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.gray400),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: verified ? AppTheme.successGreen : AppTheme.primaryOrange,
            ),
            const SizedBox(width: 4),
            Text(
              verified ? 'Oui' : 'Non',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: verified
                    ? AppTheme.successGreenDark
                    : AppTheme.primaryOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _premiumBadge(bool active) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compte Premium',
          style: TextStyle(fontSize: 12, color: AppTheme.gray400),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.star : Icons.star_border,
              size: 16,
              color: active ? AppTheme.primaryOrange : AppTheme.gray500,
            ),
            const SizedBox(width: 4),
            Text(
              active ? 'Actif' : 'Standard',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? AppTheme.primaryOrange : AppTheme.gray600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
