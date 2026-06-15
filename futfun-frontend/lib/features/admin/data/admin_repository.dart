// lib/features/admin/data/admin_repository.dart

import 'package:dio/dio.dart';
import 'models/admin_user_model.dart';
import 'models/invite_model.dart';

class AdminRepository {
  final Dio _dio;

  AdminRepository(this._dio);

  Future<List<AdminUser>> getUsers() async {
    final response = await _dio.get('/api/admin/users');
    final list = response.data['users'] as List<dynamic>;
    return list.map((e) => AdminUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminUser> updateUserRole(String userId, String role) async {
    final response = await _dio.patch(
      '/api/admin/users/$userId/role',
      data: {'role': role},
    );
    return AdminUser.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<void> deleteUser(String userId) async {
    await _dio.delete('/api/admin/users/$userId');
  }

  Future<List<InviteModel>> getInvites() async {
    final response = await _dio.get('/api/admin/invites');
    final list = response.data['invites'] as List<dynamic>;
    return list.map((e) => InviteModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<({String inviteUrl, bool emailSent})> sendInvite(String email) async {
    final response = await _dio.post('/api/admin/invites', data: {'email': email});
    return (
      inviteUrl: response.data['inviteUrl'] as String,
      emailSent: response.data['emailSent'] as bool,
    );
  }

  Future<void> cancelInvite(String inviteId) async {
    await _dio.delete('/api/admin/invites/$inviteId');
  }

  Future<({String inviteUrl, bool emailSent})> resendInvite(String inviteId) async {
    final response = await _dio.post('/api/admin/invites/$inviteId/resend');
    return (
      inviteUrl: response.data['inviteUrl'] as String,
      emailSent: response.data['emailSent'] as bool,
    );
  }
}
