// lib/screens/annonces/create_annonce_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../models/annonce.dart';
import '../../models/magasin.dart';
import '../../services/annonce_service.dart';
import '../../services/magasin_service.dart';

class CreateAnnonceScreen extends StatefulWidget {
  /// null → création, non-null → édition
  final String? adId;

  const CreateAnnonceScreen({super.key, this.adId});

  bool get isEditing => adId != null;

  @override
  State<CreateAnnonceScreen> createState() => _CreateAnnonceScreenState();
}

class _CreateAnnonceScreenState extends State<CreateAnnonceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AnnonceService();
  final _magasinService = MagasinService(); // ← NOUVEAU

  // Contrôleurs texte
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Dropdowns
  String? _selectedCategory;
  String? _selectedCity;
  String? _selectedAdType;

  // Toggles
  bool _isNegotiable = false;
  bool _isUrgent = false;

  // Date expiration
  DateTime? _expiresAt;

  // Images
  final List<File> _newImages = [];
  List<AdImage> _existingImages = [];
  final List<String> _removedImageIds = [];
  int _primaryIndex = 0;

  // ─── Magasin ──────────────────────────────────────────────────────────────
  int? _selectedMagasinId; // null = aucun magasin sélectionné
  int? _initialMagasinId; // valeur au chargement (pour détecter le détachement)
  List<MagasinSelector> _myMagasins = [];

  // Listes options
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _adTypes = [];

  // État UI
  bool _loadingData = true;
  bool _submitting = false;
  String? _globalError;

  int get _totalImages => _existingImages.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    _adTypes = _service.getAdTypes();
    _loadFormData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ─── Chargement initial ───────────────────────────────────────────────────

  Future<void> _loadFormData() async {
    setState(() => _loadingData = true);
    try {
      // Catégories + villes (même type → Future.wait sans risque)
      final results = await Future.wait([
        _service.getCategories(),
        _service.getCities(),
      ]);
      _categories = results[0];
      _cities = results[1];

      // Magasins séparément (type différent → évite le cast error Dart)
      _myMagasins = await _magasinService.getMyMagasinsSelector();

      if (widget.isEditing) {
        final ad = await _service.getAdDetail(widget.adId!);
        _prefillForm(ad);
      } else {
        if (_adTypes.isNotEmpty) _selectedAdType = _adTypes.first['value'];
      }
    } catch (e) {
      setState(
        () => _globalError = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  void _prefillForm(Ad ad) {
    _titleCtrl.text = ad.title;
    _descCtrl.text = ad.description ?? '';
    _priceCtrl.text = ad.price.toStringAsFixed(0);
    _whatsappCtrl.text = ad.whatsappNumber ?? '';
    _addressCtrl.text = ad.address ?? '';
    _selectedCategory = ad.category;
    _selectedCity = ad.city;
    _selectedAdType = ad.adType;
    _isNegotiable = ad.isNegotiable;
    _isUrgent = ad.isUrgent;
    _existingImages = List.from(ad.images);
    _selectedMagasinId = ad.magasinId; // ← NOUVEAU
    _initialMagasinId = ad.magasinId; // ← NOUVEAU
    if (ad.expiresAt != null) {
      try {
        _expiresAt = DateTime.parse(ad.expiresAt!);
      } catch (_) {}
    }
  }

  // ─── Sélection d'images ───────────────────────────────────────────────────

  Future<void> _pickImages(ImageSource source) async {
    if (_totalImages >= 5) {
      _showSnack('Maximum 5 images autorisées', isError: true);
      return;
    }
    final picker = ImagePicker();
    if (source == ImageSource.gallery) {
      final picked = await picker.pickMultiImage(imageQuality: 80);
      for (final f in picked) {
        if (_totalImages >= 5) break;
        _newImages.add(File(f.path));
      }
    } else {
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) _newImages.add(File(picked.path));
    }
    setState(() {});
  }

  void _removeExistingImage(int index) {
    setState(() {
      _removedImageIds.add(_existingImages[index].id);
      _existingImages.removeAt(index);
      if (_primaryIndex >= _totalImages && _totalImages > 0) _primaryIndex = 0;
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
      if (_primaryIndex >= _totalImages && _totalImages > 0) _primaryIndex = 0;
    });
  }

  // ─── Soumission ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _globalError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_totalImages == 0 && !widget.isEditing) {
      setState(() => _globalError = 'Ajoutez au moins une photo.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final price = double.parse(_priceCtrl.text.replaceAll(' ', ''));
      final expiresAtStr = _expiresAt != null
          ? '${_expiresAt!.toIso8601String().substring(0, 10)}T00:00:00Z'
          : null;
      final newPrimaryIdx = _primaryIndex >= _existingImages.length
          ? _primaryIndex - _existingImages.length
          : null;

      // Faut-il détacher le magasin ? (avait un magasin → on l'a retiré)
      final shouldClear =
          widget.isEditing &&
          _initialMagasinId != null &&
          _selectedMagasinId == null;

      if (widget.isEditing) {
        await _service.updateAd(
          adId: widget.adId!,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          price: price,
          category: _selectedCategory!,
          city: _selectedCity!,
          adType: _selectedAdType!,
          isNegotiable: _isNegotiable,
          isUrgent: _isUrgent,
          whatsappNumber: _whatsappCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          expiresAt: expiresAtStr,
          newImages: _newImages,
          keepImageIds: _existingImages.map((e) => e.id).toList(),
          primaryImageIndex: newPrimaryIdx,
          magasinId: _selectedMagasinId, // ← NOUVEAU
          clearMagasin: shouldClear, // ← NOUVEAU
        );
        _showSnack('Annonce mise à jour !');
      } else {
        await _service.createAd(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          price: price,
          category: _selectedCategory!,
          city: _selectedCity!,
          adType: _selectedAdType!,
          isNegotiable: _isNegotiable,
          isUrgent: _isUrgent,
          whatsappNumber: _whatsappCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          expiresAt: expiresAtStr,
          images: _newImages,
          primaryImageIndex: _newImages.isNotEmpty ? 0 : null,
          magasinId: _selectedMagasinId, // ← NOUVEAU
        );
        _showSnack('Annonce publiée avec succès ! 🎉');
      }
      if (mounted) context.go('/my-ads');
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryOrange),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier l\'annonce' : 'Publier une annonce',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/accueil'),
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
                  _buildImagesSection(),
                  const SizedBox(height: 16),
                  _buildInfoSection(),
                  const SizedBox(height: 16),
                  _buildDetailsSection(),
                  const SizedBox(height: 16),
                  _buildMagasinSection(), // ← NOUVEAU
                  const SizedBox(height: 16),
                  _buildContactSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: _loadingData ? null : _buildBottomBar(),
    );
  }

  // ─── Section photos ───────────────────────────────────────────────────────

  Widget _buildImagesSection() {
    return _SectionCard(
      title: 'Photos',
      subtitle: 'Jusqu\'à 5 photos · Toucher pour définir la principale',
      child: Column(
        children: [
          if (_totalImages > 0) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _totalImages,
              itemBuilder: (_, i) {
                final isExisting = i < _existingImages.length;
                final isPrimary = i == _primaryIndex;
                return GestureDetector(
                  onTap: () => setState(() => _primaryIndex = i),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: isExisting
                            ? Image.network(
                                _existingImages[i].imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imgPlaceholder(),
                              )
                            : Image.file(
                                _newImages[i - _existingImages.length],
                                fit: BoxFit.cover,
                              ),
                      ),
                      if (isPrimary)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primaryOrange,
                              width: 3,
                            ),
                          ),
                        ),
                      if (isPrimary)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Principale',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: isExisting
                              ? () => _removeExistingImage(i)
                              : () =>
                                    _removeNewImage(i - _existingImages.length),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          if (_totalImages < 5)
            Row(
              children: [
                Expanded(
                  child: _ImgPickerBtn(
                    icon: Icons.photo_library_outlined,
                    label: 'Galerie',
                    onTap: () => _pickImages(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ImgPickerBtn(
                    icon: Icons.camera_alt_outlined,
                    label: 'Caméra',
                    onTap: () => _pickImages(ImageSource.camera),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    color: AppTheme.gray100,
    child: const Icon(Icons.image_outlined, color: AppTheme.gray400),
  );

  // ─── Section informations ─────────────────────────────────────────────────

  Widget _buildInfoSection() {
    return _SectionCard(
      title: 'Informations principales',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Titre *'),
          TextFormField(
            controller: _titleCtrl,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().length < 5)
                ? 'Minimum 5 caractères'
                : null,
            decoration: const InputDecoration(
              hintText: 'Ex: iPhone 13 Pro 256GB',
              prefixIcon: Icon(Icons.title_outlined, color: AppTheme.gray400),
            ),
          ),
          const SizedBox(height: 16),
          _Label('Description'),
          TextFormField(
            controller: _descCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'État, caractéristiques, inclus... (optionnel)',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 64),
                child: Icon(
                  Icons.description_outlined,
                  color: AppTheme.gray400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Label('Prix (FCFA) *'),
          TextFormField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Champ requis';
              if (double.tryParse(v) == null || double.parse(v) <= 0)
                return 'Prix invalide';
              return null;
            },
            decoration: const InputDecoration(
              hintText: '50000',
              prefixIcon: Icon(
                Icons.payments_outlined,
                color: AppTheme.gray400,
              ),
              suffixText: 'FCFA',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  icon: Icons.handshake_outlined,
                  label: 'Négociable',
                  active: _isNegotiable,
                  onTap: () => setState(() => _isNegotiable = !_isNegotiable),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToggleChip(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Urgent',
                  active: _isUrgent,
                  activeColor: AppTheme.errorRed,
                  onTap: () => setState(() => _isUrgent = !_isUrgent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section détails ──────────────────────────────────────────────────────

  Widget _buildDetailsSection() {
    return _SectionCard(
      title: 'Détails',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Type d\'annonce *'),
          DropdownButtonFormField<String>(
            value: _selectedAdType,
            validator: (v) => v == null ? 'Requis' : null,
            onChanged: (v) => setState(() => _selectedAdType = v),
            decoration: const InputDecoration(hintText: 'Choisir un type'),
            items: _adTypes
                .map(
                  (e) => DropdownMenuItem(
                    value: e['value'] as String,
                    child: Text(e['label'] as String),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _Label('Catégorie *'),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            validator: (v) => v == null ? 'Requis' : null,
            onChanged: (v) => setState(() => _selectedCategory = v),
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
          const SizedBox(height: 16),
          _Label('Ville *'),
          DropdownButtonFormField<String>(
            value: _selectedCity,
            validator: (v) => v == null ? 'Requis' : null,
            onChanged: (v) => setState(() => _selectedCity = v),
            decoration: const InputDecoration(hintText: 'Choisir une ville'),
            items: _cities
                .map(
                  (e) => DropdownMenuItem(
                    value: e['value'] as String,
                    child: Text(e['label'] as String? ?? ''),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _Label('Date d\'expiration (optionnel)'),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.gray200, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppTheme.gray400,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _expiresAt != null
                          ? '${_expiresAt!.day.toString().padLeft(2, '0')}/'
                                '${_expiresAt!.month.toString().padLeft(2, '0')}/'
                                '${_expiresAt!.year}'
                          : 'Sélectionner une date',
                      style: TextStyle(
                        color: _expiresAt != null
                            ? AppTheme.gray900
                            : AppTheme.gray400,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (_expiresAt != null)
                    GestureDetector(
                      onTap: () => setState(() => _expiresAt = null),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppTheme.gray400,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section magasin (NOUVEAU) ────────────────────────────────────────────

  Widget _buildMagasinSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC80), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppTheme.primaryOrange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rattacher à un magasin',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.gray900,
                      ),
                    ),
                    Text(
                      'Optionnel',
                      style: TextStyle(fontSize: 11, color: AppTheme.gray500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Corps
          if (_myMagasins.isEmpty)
            _buildNoMagasin()
          else
            _buildMagasinDropdown(),
        ],
      ),
    );
  }

  Widget _buildNoMagasin() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Vous n\'avez pas encore de magasin.',
              style: TextStyle(fontSize: 13, color: AppTheme.gray500),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/create-magasin'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Créer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMagasinDropdown() {
    // S'assurer que la valeur sélectionnée existe dans la liste
    final validId = _myMagasins.any((m) => m.id == _selectedMagasinId)
        ? _selectedMagasinId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int?>(
          value: validId,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFFFCC80),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFFFCC80),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2),
            ),
          ),
          hint: const Text(
            '-- Aucun magasin --',
            style: TextStyle(color: AppTheme.gray400, fontSize: 14),
          ),
          onChanged: (v) => setState(() => _selectedMagasinId = v),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text(
                '-- Aucun magasin --',
                style: TextStyle(color: AppTheme.gray500, fontSize: 14),
              ),
            ),
            ..._myMagasins.map(
              (m) => DropdownMenuItem<int?>(
                value: m.id,
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          m.nom.isNotEmpty ? m.nom[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${m.nom}'
                        '${(m.marche != null && m.marche!.isNotEmpty) ? ' — ${m.marche}' : ''}'
                        ' (${m.ville})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.gray900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_selectedMagasinId != null) ...[
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.info_outline, size: 13, color: AppTheme.gray400),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Les acheteurs retrouveront cette annonce sur la page du magasin.',
                  style: TextStyle(fontSize: 11, color: AppTheme.gray500),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─── Section contact ──────────────────────────────────────────────────────

  Widget _buildContactSection() {
    return _SectionCard(
      title: 'Contact & Localisation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('WhatsApp (optionnel)'),
          TextFormField(
            controller: _whatsappCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: '+225 07 00 00 00 00',
              prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.gray400),
            ),
          ),
          const SizedBox(height: 16),
          _Label('Adresse précise (optionnel)'),
          TextFormField(
            controller: _addressCtrl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Quartier, rue...',
              prefixIcon: Icon(
                Icons.location_on_outlined,
                color: AppTheme.gray400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Barre du bas ─────────────────────────────────────────────────────────

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
            boxShadow: _submitting
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.primaryOrange.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                  widget.isEditing ? Icons.save_outlined : Icons.send_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Text(
                _submitting
                    ? 'Publication...'
                    : (widget.isEditing
                          ? 'Enregistrer les modifications'
                          : 'Publier l\'annonce'),
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
}

// ─── Widgets internes ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
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
}

class _ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppTheme.primaryOrange;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.10) : AppTheme.gray100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? color : AppTheme.gray500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? color : AppTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImgPickerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ImgPickerBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primaryOrange.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryOrange, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
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
}
