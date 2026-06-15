// lib/features/auth/data/models/auth_user.dart

enum UserRole { pending, member, admin }

UserRole parseUserRole(String role) {
  switch (role.toUpperCase()) {
    case 'ADMIN':
      return UserRole.admin;
    case 'MEMBER':
      return UserRole.member;
    default:
      return UserRole.pending;
  }
}

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: parseUserRole(json['role'] as String? ?? 'PENDING'),
    );
  }
}
