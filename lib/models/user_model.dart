class UserModel {
  final int? id;
  final String? kodeSales;
  final String name;
  final String email;
  final String? phone;
  final String? alamat;
  final String? tanggalBergabung;
  final String? photoUrl;
  final String role; // 'superadmin', 'administrator' / 'admin', 'sales'
  final bool isActive;
  final String membershipStatus; // 'aktif', 'nonaktif', 'ditangguhkan'
  final int? koordinatorId;
  final String? koordinatorName;
  final String? googleId;
  final String? googleEmail;
  final DateTime? lastLoginAt;

  const UserModel({
    this.id,
    this.kodeSales,
    required this.name,
    required this.email,
    this.phone,
    this.alamat,
    this.tanggalBergabung,
    this.photoUrl,
    this.role = 'sales',
    this.isActive = true,
    String? membershipStatus,
    this.koordinatorId,
    this.koordinatorName,
    this.googleId,
    this.googleEmail,
    this.lastLoginAt,
  }) : membershipStatus = membershipStatus ?? (isActive ? 'aktif' : 'nonaktif');

  bool get isSuperAdmin =>
      role.toLowerCase() == 'superadmin' || role.toLowerCase() == 'owner';
  bool get isAdmin =>
      role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrator';
  bool get isSales => role.toLowerCase() == 'sales';
  bool get isManager => isSuperAdmin || isAdmin;
  bool get isSuspended => membershipStatus.toLowerCase() == 'ditangguhkan';
  bool get isGoogleLinked => googleId != null && googleId!.isNotEmpty;
  String get displayGoogleEmail =>
      googleEmail?.isNotEmpty == true ? googleEmail! : (isGoogleLinked ? email : '');

  String get displayKodeSales {
    if (kodeSales != null && kodeSales!.trim().isNotEmpty) return kodeSales!;
    if (isSales && id != null) return 'SLS-${id.toString().padLeft(3, '0')}';
    return '-';
  }

  String get membershipStatusLabel {
    switch (membershipStatus.toLowerCase()) {
      case 'ditangguhkan':
        return 'Ditangguhkan';
      case 'nonaktif':
        return 'Nonaktif';
      case 'aktif':
      default:
        return isActive ? 'Aktif' : 'Nonaktif';
    }
  }

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
    final bool active = json['is_active'] == 1 ||
        json['is_active'] == true ||
        json['isActive'] == true ||
        json['is_active'] == '1';
    final rawStatus = (json['membership_status'] as String?)?.toLowerCase();
    final String resolvedStatus = (rawStatus != null &&
            ['aktif', 'nonaktif', 'ditangguhkan'].contains(rawStatus))
        ? rawStatus
        : (active ? 'aktif' : 'nonaktif');

    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      kodeSales: json['kode_sales'] as String? ?? json['kodeSales'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      alamat: json['alamat'] as String?,
      tanggalBergabung:
          json['tanggal_bergabung'] as String? ?? json['tanggalBergabung'] as String?,
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      role: json['role'] as String? ?? 'sales',
      isActive: active && resolvedStatus == 'aktif',
      membershipStatus: resolvedStatus,
      koordinatorId: json['koordinator_id'] is int
          ? json['koordinator_id'] as int
          : int.tryParse(json['koordinator_id']?.toString() ?? ''),
      koordinatorName: json['koordinator_name'] as String?,
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
      if (kodeSales != null) 'kode_sales': kodeSales,
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (alamat != null) 'alamat': alamat,
      if (tanggalBergabung != null) 'tanggal_bergabung': tanggalBergabung,
      if (photoUrl != null) 'photo_url': photoUrl,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'membership_status': membershipStatus,
      if (koordinatorId != null) 'koordinator_id': koordinatorId,
      if (koordinatorName != null) 'koordinator_name': koordinatorName,
      if (googleId != null) 'google_id': googleId,
      if (googleEmail != null) 'google_email': googleEmail,
      if (lastLoginAt != null) 'last_login_at': lastLoginAt!.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    String? kodeSales,
    String? name,
    String? email,
    String? phone,
    String? alamat,
    String? tanggalBergabung,
    String? photoUrl,
    String? role,
    bool? isActive,
    String? membershipStatus,
    int? koordinatorId,
    String? koordinatorName,
    String? googleId,
    String? googleEmail,
    DateTime? lastLoginAt,
  }) {
    final nextActive = isActive ?? this.isActive;
    final nextStatus = membershipStatus ??
        (isActive != null ? (nextActive ? 'aktif' : 'nonaktif') : this.membershipStatus);
    return UserModel(
      id: id ?? this.id,
      kodeSales: kodeSales ?? this.kodeSales,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      alamat: alamat ?? this.alamat,
      tanggalBergabung: tanggalBergabung ?? this.tanggalBergabung,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isActive: nextActive,
      membershipStatus: nextStatus,
      koordinatorId: koordinatorId ?? this.koordinatorId,
      koordinatorName: koordinatorName ?? this.koordinatorName,
      googleId: googleId ?? this.googleId,
      googleEmail: googleEmail ?? this.googleEmail,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

class MembershipStatusLog {
  final int id;
  final int userId;
  final String oldStatus;
  final String newStatus;
  final String reason;
  final String changedByName;
  final DateTime createdAt;

  const MembershipStatusLog({
    required this.id,
    required this.userId,
    required this.oldStatus,
    required this.newStatus,
    required this.reason,
    required this.changedByName,
    required this.createdAt,
  });

  factory MembershipStatusLog.fromJson(Map<String, dynamic> json) {
    return MembershipStatusLog(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      oldStatus: json['old_status']?.toString() ?? '-',
      newStatus: json['new_status']?.toString() ?? 'aktif',
      reason: json['reason']?.toString() ?? '',
      changedByName: json['changed_by_name']?.toString() ?? 'Admin',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'old_status': oldStatus,
        'new_status': newStatus,
        'reason': reason,
        'changed_by_name': changedByName,
        'created_at': createdAt.toIso8601String(),
      };
}
