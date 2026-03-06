// lib/models/user.dart

class User {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? avatar;
  final String? location;
  final String? bio;
  final bool emailVerified;
  final bool phoneVerified;
  final bool isPremiumActive;
  final String? createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.avatar,
    this.location,
    this.bio,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.isPremiumActive = false,
    this.createdAt,
  });

  String get fullName {
    final fn = firstName ?? '';
    final ln = lastName ?? '';
    final name = '$fn $ln'.trim();
    return name.isNotEmpty ? name : username;
  }

  String? get avatarUrl {
    if (avatar == null) return null;
    if (avatar!.startsWith('http')) return avatar;
    return 'https://www.eburnie-market.com$avatar';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      phoneNumber: json['phone_number'],
      avatar: json['avatar'],
      location: json['location'],
      bio: json['bio'],
      emailVerified: json['email_verified'] ?? false,
      phoneVerified: json['phone_verified'] ?? false,
      isPremiumActive: json['is_premium_active'] ?? false,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'avatar': avatar,
      'location': location,
      'bio': bio,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
      'is_premium_active': isPremiumActive,
      'created_at': createdAt,
    };
  }
}

class AuthResponse {
  final String token;
  final User user;
  final bool created;

  AuthResponse({required this.token, required this.user, this.created = false});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
      created: json['created'] ?? false,
    );
  }
}
