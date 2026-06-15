// lib/features/admin/data/models/admin_user_model.dart

import '../../../auth/data/models/auth_user.dart';

class AdminUser {
  final String id;
  final String email;
  final String displayName;
  final String provider;
  final UserRole role;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    required this.role,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      provider: json['provider'] as String,
      role: parseUserRole(json['role'] as String? ?? 'PENDING'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
    );
  }
}
