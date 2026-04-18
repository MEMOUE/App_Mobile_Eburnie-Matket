// lib/screens/magasin/new_magasin_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_theme.dart';
import '../../models/magasin.dart';
import '../../services/magasin_service.dart';
import '../../services/annonce_service.dart';

class NewMagasinScreen extends StatefulWidget {
  final int? magasinId;

  const NewMagasinScreen({super.key, this.magasinId});

  bool get isEditing => magasinId != null;

  @override
  State<NewMagasinScreen> createState() => _NewMagasinScreenState();
}

class _NewMagasinScreenState extends State<NewMagasinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = MagasinService();

  // Contrôleurs
  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _standCtrl = TextEditingController();

  // Dropdowns
  String? _selectedCategorie;
  String? _selectedVille;
  String? _selectedMarche;
  bool _isActive = true;

  // Logo
  File? _newLogo;
  String? _existingLogoUrl;

  // Référentiels
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _cities = [];
  List<Marche> _marches = [];
  List<Marche> _filteredMarches = [];

  // État
  bool _loadingData = true;
  bool _submitting = false;
  bool _locating = false;
  String? _globalError;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _adresseCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _telCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _standCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() => _loadingData = true);
    try {
      final results = await Future.wait([
        AnnonceService().getCategories(),
        AnnonceService().getCities(),
        _service.getMarches(),
      ]);
      _categories = results[0] as List<Map<String, dynamic>>;
      _cities = results[1] as List<Map<String, dynamic>>;
      _marches = results[2] as List<Marche>;

      if (widget.isEditing) {
        final m = await _service.getMagasin(widget.magasinId!);
        _prefillForm(m);
      }
    } catch (e) {
      setState(
        () => _globalError = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  void _prefillForm(Magasin m) {
    _nomCtrl.text = m.nom;
    _descCtrl.text = m.description ?? '';
    _adresseCtrl.text = m.adresse ?? '';
    _latCtrl.text = m.latitude?.toString() ?? '';
    _lngCtrl.text = m.longitude?.toString() ?? '';
    _telCtrl.text = m.telephone ?? '';
    _whatsappCtrl.text = m.whatsapp ?? '';
    _emailCtrl.text = m.emailContact ?? '';
    _standCtrl.text = m.numeroStand ?? '';
    _selectedCategorie = m.categorie;
    _selectedVille = m.ville;
    _selectedMarche = m.marche;
    _isActive = m.isActive;
    _existingLogoUrl = m.logoAbsoluteUrl;
    _filterMarches();
  }

  void _filterMarches() {
    setState(() {
      _filteredMarches = _selectedVille != null && _selectedVille!.isNotEmpty
          ? _marches.where((m) => m.villeCode == _selectedVille).toList()
          : [];
    });
  }

  Future<void> _pickLogo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked != null) {
      setState(() {
        _newLogo = File(picked.path);
        _existingLogoUrl = null;
      });
    }
  }

  Future<void> _useGPS() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack(
          'Activez la géolocalisation sur votre appareil',
          isError: true,
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Permission de localisation refusée', isError: true);
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latCtrl.text = pos.latitude.toStringAsFixed(6);
      _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      _showSnack('Position GPS récupérée ✅');
    } catch (e) {
      _showSnack('Impossible d\'obtenir la position GPS', isError: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _globalError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final lat = _latCtrl.text.isNotEmpty
          ? double.tryParse(_latCtrl.text)
          : null;
      final lng = _lngCtrl.text.isNotEmpty
          ? double.tryParse(_lngCtrl.text)
          : null;

      if (widget.isEditing) {
        await _service.updateMagasin(
          id: widget.magasinId!,
          nom: _nomCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          categorie: _selectedCategorie!,
          ville: _selectedVille!,
          marche: _selectedMarche,
          numeroStand: _standCtrl.text.trim(),
          adresse: _adresseCtrl.text.trim(),
          latitude: lat,
          longitude: lng,
          telephone: _telCtrl.text.trim(),
          whatsapp: _whatsappCtrl.text.trim(),
          emailContact: _emailCtrl.text.trim(),
          isActive: _isActive,
          logo: _newLogo,
        );
        _showSnack('Magasin modifié avec succès !');
      } else {
        await _service.createMagasin(
          nom: _nomCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          categorie: _selectedCategorie!,
          ville: _selectedVille!,
          marche: _selectedMarche,
          numeroStand: _standCtrl.text.trim(),
          adresse: _adresseCtrl.text.trim(),
          latitude: lat,
          longitude: lng,
          telephone: _telCtrl.text.trim(),
          whatsapp: _whatsappCtrl.text.trim(),
          emailContact: _emailCtrl.text.trim(),
          isActive: _isActive,
          logo: _newLogo,
        );
        _showSnack('Magasin créé avec succès ! 🎉');
      }
      if (mounted) context.go('/my-magasins');
    } catch (e) {
      setState(() {
        _globalError = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier le magasin' : 'Créer un magasin',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/my-magasins'),
        ),
      ),
      body: _loadingData
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_globalError != null) ...[
                    _ErrorBanner(message: _globalError!),
                    const SizedBox(height: 12),
                  ],
                  _buildLogoSection(),
                  const SizedBox(height: 16),
                  _buildInfoSection(),
                  const SizedBox(height: 16),
                  _buildLocationSection(),
                  const SizedBox(height: 16),
                  _buildContactSection(),
                  const SizedBox(height: 16),
                  _buildStatusSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: _loadingData ? null : _buildBottomBar(),
    );
  }

  // ─── Sections ─────────────────────────────────────────────────────────────

  Widget _buildLogoSection() {
    return _SectionCard(
      title: 'Logo du magasin',
      subtitle: '2Mo max · JPG, PNG, WEBP',
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showLogoOptions(),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _newLogo != null || _existingLogoUrl != null
                      ? AppTheme.primaryOrange
                      : AppTheme.gray200,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _newLogo != null
                    ? Image.file(_newLogo!, fit: BoxFit.cover)
                    : _existingLogoUrl != null
                    ? Image.network(
                        _existingLogoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _logoPlaceholder(),
                      )
                    : _logoPlaceholder(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showLogoOptions(),
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Choisir un logo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
                if (_newLogo != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _newLogo = null;
                      _existingLogoUrl = null;
                    }),
                    child: const Text(
                      'Supprimer',
                      style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppTheme.primaryOrange,
              ),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickLogo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppTheme.primaryOrange,
              ),
              title: const Text('Caméra'),
              onTap: () {
                Navigator.pop(context);
                _pickLogo(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return _SectionCard(
      title: 'Informations principales',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Nom du magasin *'),
          TextFormField(
            controller: _nomCtrl,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().length < 3)
                ? 'Minimum 3 caractères'
                : null,
            decoration: const InputDecoration(
              hintText: 'Ex: Électro Koumassi',
              prefixIcon: Icon(
                Icons.storefront_outlined,
                color: AppTheme.gray400,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Label('Description'),
          TextFormField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Décrivez votre magasin, vos produits... (optionnel)',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 56),
                child: Icon(
                  Icons.description_outlined,
                  color: AppTheme.gray400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Label('Catégorie principale *'),
          DropdownButtonFormField<String>(
            value: _selectedCategorie,
            validator: (v) => v == null ? 'Requis' : null,
            onChanged: (v) => setState(() => _selectedCategorie = v),
            decoration: const InputDecoration(
              hintText: 'Choisir une catégorie',
            ),
            items: _categories
                .map(
                  (e) => DropdownMenuItem(
                    value: e['value'] as String,
                    child: Text(e['label'] as String? ?? ''),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _SectionCard(
      title: 'Localisation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Ville *'),
                    DropdownButtonFormField<String>(
                      value: _selectedVille,
                      validator: (v) => v == null ? 'Requis' : null,
                      onChanged: (v) => setState(() {
                        _selectedVille = v;
                        _selectedMarche = null;
                        _filterMarches();
                      }),
                      decoration: const InputDecoration(hintText: 'Choisir'),
                      items: _cities
                          .map(
                            (e) => DropdownMenuItem(
                              value: e['value'] as String,
                              child: Text(e['label'] as String? ?? ''),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              if (_filteredMarches.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Marché'),
                      DropdownButtonFormField<String>(
                        value: _selectedMarche,
                        onChanged: (v) => setState(() => _selectedMarche = v),
                        decoration: const InputDecoration(
                          hintText: 'Optionnel',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Aucun'),
                          ),
                          ..._filteredMarches.map(
                            (m) => DropdownMenuItem(
                              value: m.value,
                              child: Text(m.label),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (_selectedMarche != null) ...[
            const SizedBox(height: 16),
            _Label('Numéro / emplacement du stand'),
            TextFormField(
              controller: _standCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Ex: Stand B-12, Allée 3...',
                prefixIcon: Icon(Icons.tag, color: AppTheme.gray400),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Label('Adresse précise (optionnel)'),
          TextFormField(
            controller: _adresseCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Ex: Rue des Jardins, face au supermarché...',
              prefixIcon: Icon(Icons.home_outlined, color: AppTheme.gray400),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Coordonnées GPS (optionnel)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _locating ? null : _useGPS,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.infoBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Ma position',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: '5.345678',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lngCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: '-4.012345',
                  ),
                ),
              ),
            ],
          ),
          if (_latCtrl.text.isNotEmpty && _lngCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.successGreen,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'GPS : ${_latCtrl.text}, ${_lngCtrl.text}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return _SectionCard(
      title: 'Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Téléphone'),
          TextFormField(
            controller: _telCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: '+225 07 00 00 00 00',
              prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.gray400),
            ),
          ),
          const SizedBox(height: 16),
          _Label('WhatsApp'),
          TextFormField(
            controller: _whatsappCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: '+225 07 00 00 00 00',
              prefixIcon: Icon(Icons.chat_outlined, color: AppTheme.gray400),
            ),
          ),
          const SizedBox(height: 16),
          _Label('Email de contact'),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              if (!v.contains('@')) return 'Email invalide';
              return null;
            },
            decoration: const InputDecoration(
              hintText: 'contact@magasin.com',
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.gray400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return _SectionCard(
      title: 'Statut',
      child: GestureDetector(
        onTap: () => setState(() => _isActive = !_isActive),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isActive ? AppTheme.successGreenLight : AppTheme.gray100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isActive ? AppTheme.successGreen : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isActive
                    ? Icons.store_outlined
                    : Icons.store_mall_directory_outlined,
                color: _isActive ? AppTheme.successGreen : AppTheme.gray500,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Magasin ${_isActive ? 'actif' : 'inactif'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _isActive
                            ? AppTheme.successGreen
                            : AppTheme.gray600,
                      ),
                    ),
                    Text(
                      _isActive
                          ? 'Visible publiquement sur Éburnie-Market'
                          : 'Non visible par les autres utilisateurs',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: AppTheme.successGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _submitting ? null : _submit,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: _submitting ? null : AppTheme.primaryGradient,
            color: _submitting ? AppTheme.gray200 : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_submitting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  widget.isEditing
                      ? Icons.save_outlined
                      : Icons.storefront_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Text(
                _submitting
                    ? 'Enregistrement...'
                    : (widget.isEditing
                          ? 'Enregistrer les modifications'
                          : 'Créer mon magasin'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoPlaceholder() => Container(
    color: AppTheme.primaryOrangeLight,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.storefront_outlined,
          color: AppTheme.primaryOrange,
          size: 28,
        ),
        const SizedBox(height: 4),
        const Text(
          'Logo',
          style: TextStyle(color: AppTheme.gray400, fontSize: 10),
        ),
      ],
    ),
  );
}

// ─── Widgets internes ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.gray900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
          ),
        ],
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.gray700,
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.errorRedLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.errorRed.withOpacity(0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Color(0xFF991B1B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
