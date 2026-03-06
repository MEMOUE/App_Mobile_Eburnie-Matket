// lib/widgets/app_widgets.dart

import 'package:flutter/material.dart';
import '../config/app_theme.dart';

// ─── Bouton principal orange avec gradient ────────────────────────────────────

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null || loading
              ? null
              : AppTheme.primaryGradient,
          color: onPressed == null || loading ? AppTheme.gray400 : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: onPressed == null || loading
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: loading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      loadingLabel ?? 'Chargement...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Bouton secondaire gris ──────────────────────────────────────────────────

class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gray200,
          foregroundColor: AppTheme.gray700,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bouton Google ────────────────────────────────────────────────────────────

class GoogleButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const GoogleButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.gray200, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.white,
        ),
        child: loading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.gray500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Connexion en cours...',
                    style: TextStyle(
                      color: AppTheme.gray700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icône G de Google
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: const Text(
                      'G',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFEA4335),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.gray700,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Champ texte avec icône ──────────────────────────────────────────────────

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? errorText;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.placeholder,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          obscureText: obscureText,
          keyboardType: keyboardType,
          readOnly: readOnly,
          maxLines: maxLines,
          maxLength: maxLength,
          textInputAction: textInputAction,
          onTap: onTap,
          onChanged: onChanged,
          style: const TextStyle(color: AppTheme.gray900, fontSize: 15),
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppTheme.gray400, size: 20)
                : null,
            suffixIcon: suffixIcon,
            errorText: errorText,
            filled: true,
            fillColor: readOnly ? AppTheme.gray100 : Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─── Message de succès / erreur / info ───────────────────────────────────────

enum MessageType { success, error, info, warning }

class AppMessage extends StatelessWidget {
  final String text;
  final MessageType type;

  const AppMessage({super.key, required this.text, required this.type});

  @override
  Widget build(BuildContext context) {
    final config = _config();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.background,
        border: Border.all(color: config.border, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(config.icon, color: config.iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: config.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _MessageConfig _config() {
    switch (type) {
      case MessageType.success:
        return _MessageConfig(
          background: AppTheme.successGreenLight,
          border: AppTheme.successGreen,
          icon: Icons.check_circle_outline,
          iconColor: AppTheme.successGreenDark,
          textColor: const Color(0xFF166534),
        );
      case MessageType.error:
        return _MessageConfig(
          background: AppTheme.errorRedLight,
          border: AppTheme.errorRed,
          icon: Icons.error_outline,
          iconColor: AppTheme.errorRedDark,
          textColor: const Color(0xFF991B1B),
        );
      case MessageType.info:
        return _MessageConfig(
          background: AppTheme.infoBlueLight,
          border: AppTheme.infoBlue,
          icon: Icons.info_outline,
          iconColor: AppTheme.infoBlue,
          textColor: const Color(0xFF1E40AF),
        );
      case MessageType.warning:
        return _MessageConfig(
          background: const Color(0xFFFEF3C7),
          border: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_outlined,
          iconColor: const Color(0xFFD97706),
          textColor: const Color(0xFF92400E),
        );
    }
  }
}

class _MessageConfig {
  final Color background, border, iconColor, textColor;
  final IconData icon;
  _MessageConfig({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.textColor,
  });
}

// ─── Séparateur "Ou" ──────────────────────────────────────────────────────────

class OrDivider extends StatelessWidget {
  final String text;
  const OrDivider({super.key, this.text = 'Ou connectez-vous avec'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.gray200, thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.gray500, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: AppTheme.gray200, thickness: 1.5)),
      ],
    );
  }
}

// ─── Card avec gradient de fond ──────────────────────────────────────────────

class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: child,
    );
  }
}

// ─── PasswordField avec toggle ────────────────────────────────────────────────

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.placeholder,
    this.errorText,
    this.textInputAction,
    this.onChanged,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      placeholder: widget.placeholder,
      obscureText: _obscure,
      errorText: widget.errorText,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      prefixIcon: Icons.lock_outline,
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppTheme.gray400,
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

// ─── Security Info Card ───────────────────────────────────────────────────────

class SecurityInfoCard extends StatelessWidget {
  const SecurityInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Icon(
                Icons.shield_outlined,
                color: AppTheme.primaryOrange,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Sécurité',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _item('Le lien de réinitialisation est valide pendant 24 heures'),
          _item('Chaque lien ne peut être utilisé qu\'une seule fois'),
          _item('Vos données sont protégées et sécurisées'),
        ],
      ),
    );
  }

  Widget _item(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppTheme.successGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
            ),
          ),
        ],
      ),
    );
  }
}
