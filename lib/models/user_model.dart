class UserModel {
  final int? id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final String role; // 'superadmin', 'administrator' / 'admin', 'sales'
  final bool isActive;
  final String? googleId;
  final String? googleEmail;
  final DateTime? lastLoginAt;

  const UserModel({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.role = 'sales',
    this.isActive = true,
    this.googleId,
    this.googleEmail,
    this.lastLoginAt,
  });

  bool get isSuperAdmin =>
      role.toLowerCase() == 'superadmin' || role.toLowerCase() == 'owner';
  bool get isAdmin =>
      role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrator';
  bool get isSales => role.toLowerCase() == 'sales';
  bool get isManager => isSuperAdmin || isAdmin;
  bool get isGoogleLinked => googleId != null && googleId!.isNotEmpty;
  String get displayGoogleEmail =>
      googleEmail?.isNotEmpty == true ? googleEmail! : (isGoogleLinked ? email : '');

  String get roleDisplayTitle {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return 'Superadmin (Owner)';
      case 'administrator':
      case 'admin':
        return 'Administrator (Sekretaris)';
      case 'sales':
      default:
        return 'Sales Lapangan';
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      role: json['role'] as String? ?? 'sales',
      isActive: json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['isActive'] == true ||
          json['is_active'] == '1',
      googleId: json['google_id'] as String? ?? json['googleId'] as String?,
      googleEmail: json['google_email'] as String? ?? json['googleEmail'] as String?,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'].toString())
          : (json['lastLoginAt'] != null
              ? DateTime.tryParse(json['lastLoginAt'].toString())
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photo_url': photoUrl,
      'role': role,
      'is_active': isActive ? 1 : 0,
      if (googleId != null) 'google_id': googleId,
      if (googleEmail != null) 'google_email': googleEmail,
      if (lastLoginAt != null) 'last_login_at': lastLoginAt!.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? role,
    bool? isActive,
    String? googleId,
    String? googleEmail,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      googleId: googleId ?? this.googleId,
      googleEmail: googleEmail ?? this.googleEmail,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
