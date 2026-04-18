// lib/models/magasin.dart
import '../config/app_config.dart';

// ─── Propriétaire d'un magasin ─────────────────────────────────────────────

class MagasinOwner {
  final int id;
  final String username;
  final String fullName;
  final String? avatar;
  final bool isPremium;

  const MagasinOwner({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatar,
    this.isPremium = false,
  });

  String? get avatarUrl {
    if (avatar == null || avatar!.isEmpty) return null;
    if (avatar!.startsWith('http')) return avatar;
    return '${AppConfig.mediaUrl}$avatar';
  }

  factory MagasinOwner.fromJson(Map<String, dynamic> json) => MagasinOwner(
    id: json['id'] ?? 0,
    username: json['username'] ?? '',
    fullName: json['full_name'] ?? json['username'] ?? '',
    avatar: json['avatar'],
    isPremium: json['is_premium'] ?? false,
  );
}

// ─── Modèle principal Magasin ──────────────────────────────────────────────

class Magasin {
  final int id;
  final String nom;
  final String? description;
  final String? logoUrl;
  final String categorie;
  final String categorieDisplay;
  final String ville;
  final String villeDisplay;
  final String? marche;
  final String? marcheDisplay;
  final String? numeroStand;
  final String? adresse;
  final double? latitude;
  final double? longitude;
  final String? telephone;
  final String? whatsapp;
  final String? emailContact;
  final bool isActive;
  final bool isVerified;
  final int nbAnnonces;
  final bool isOwner;
  final MagasinOwner? owner;
  final String? ownerName;
  final String? createdAt;

  const Magasin({
    required this.id,
    required this.nom,
    this.description,
    this.logoUrl,
    required this.categorie,
    required this.categorieDisplay,
    required this.ville,
    required this.villeDisplay,
    this.marche,
    this.marcheDisplay,
    this.numeroStand,
    this.adresse,
    this.latitude,
    this.longitude,
    this.telephone,
    this.whatsapp,
    this.emailContact,
    this.isActive = true,
    this.isVerified = false,
    this.nbAnnonces = 0,
    this.isOwner = false,
    this.owner,
    this.ownerName,
    this.createdAt,
  });

  String get initials {
    final words = nom.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) return nom[0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  String? get logoAbsoluteUrl {
    if (logoUrl == null || logoUrl!.isEmpty) return null;
    if (logoUrl!.startsWith('http')) return logoUrl;
    return '${AppConfig.mediaUrl}$logoUrl';
  }

  bool get hasLocation =>
      villeDisplay.isNotEmpty ||
      (marcheDisplay?.isNotEmpty ?? false) ||
      (adresse?.isNotEmpty ?? false) ||
      latitude != null;

  bool get hasContact =>
      (telephone?.isNotEmpty ?? false) ||
      (whatsapp?.isNotEmpty ?? false) ||
      (emailContact?.isNotEmpty ?? false);

  factory Magasin.fromJson(Map<String, dynamic> json) => Magasin(
    id: json['id'] ?? 0,
    nom: json['nom'] ?? '',
    description: json['description'],
    logoUrl: json['logo_url'],
    categorie: json['categorie'] ?? '',
    categorieDisplay: json['categorie_display'] ?? json['categorie'] ?? '',
    ville: json['ville'] ?? '',
    villeDisplay: json['ville_display'] ?? json['ville'] ?? '',
    marche: json['marche'],
    marcheDisplay: json['marche_display'],
    numeroStand: json['numero_stand'],
    adresse: json['adresse'],
    latitude: _parseDouble(json['latitude']),
    longitude: _parseDouble(json['longitude']),
    telephone: json['telephone'],
    whatsapp: json['whatsapp'],
    emailContact: json['email_contact'],
    isActive: json['is_active'] ?? true,
    isVerified: json['is_verified'] ?? false,
    nbAnnonces: json['nb_annonces'] ?? 0,
    isOwner: json['is_owner'] ?? false,
    owner: json['owner'] is Map
        ? MagasinOwner.fromJson(json['owner'] as Map<String, dynamic>)
        : null,
    ownerName: json['owner_name'],
    createdAt: json['created_at'],
  );

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

// ─── Marché (référentiel) ─────────────────────────────────────────────────

class Marche {
  final String value;
  final String label;
  final String villeCode;

  const Marche({
    required this.value,
    required this.label,
    required this.villeCode,
  });

  factory Marche.fromJson(Map<String, dynamic> json) => Marche(
    value: json['value']?.toString() ?? '',
    label: json['label'] ?? '',
    villeCode: json['ville_code'] ?? '',
  );
}

// ─── Sélecteur léger (utilisé dans le formulaire annonce) ─────────────────

class MagasinSelector {
  final int id;
  final String nom;
  final String ville;
  final String? marche;

  const MagasinSelector({
    required this.id,
    required this.nom,
    required this.ville,
    this.marche,
  });

  factory MagasinSelector.fromJson(Map<String, dynamic> json) =>
      MagasinSelector(
        id: json['id'] ?? 0,
        nom: json['nom'] ?? '',
        ville: json['ville'] ?? '',
        marche: json['marche'],
      );
}
