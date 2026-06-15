// lib/features/admin/data/models/invite_model.dart

enum InviteStatus { pending, used, expired }

class InviteModel {
  final String id;
  final String email;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;
  final String? creatorName;

  const InviteModel({
    required this.id,
    required this.email,
    required this.expiresAt,
    this.usedAt,
    required this.createdAt,
    this.creatorName,
  });

  InviteStatus get status {
    if (usedAt != null) return InviteStatus.used;
    if (expiresAt.isBefore(DateTime.now())) return InviteStatus.expired;
    return InviteStatus.pending;
  }

  factory InviteModel.fromJson(Map<String, dynamic> json) {
    return InviteModel(
      id: json['id'] as String,
      email: json['email'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      usedAt: json['usedAt'] != null ? DateTime.parse(json['usedAt'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      creatorName: (json['creator'] as Map<String, dynamic>?)?['displayName'] as String?,
    );
  }
}
