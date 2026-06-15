// lib/features/admin/viewmodels/admin_users_viewmodel.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';
import '../data/models/admin_user_model.dart';
import '../../../core/network/dio_client.dart';

class AdminUsersViewModel extends AsyncNotifier<List<AdminUser>> {
  final _repository = AdminRepository(DioClient().dio);

  @override
  Future<List<AdminUser>> build() async {
    return _repository.getUsers();
  }

  Future<void> approveUser(String userId) async {
    await _repository.updateUserRole(userId, 'MEMBER');
    ref.invalidateSelf();
  }

  Future<void> promoteToAdmin(String userId) async {
    await _repository.updateUserRole(userId, 'ADMIN');
    ref.invalidateSelf();
  }

  Future<void> demoteToMember(String userId) async {
    await _repository.updateUserRole(userId, 'MEMBER');
    ref.invalidateSelf();
  }

  Future<void> removeUser(String userId) async {
    await _repository.deleteUser(userId);
    ref.invalidateSelf();
  }
}

final adminUsersViewModelProvider =
    AsyncNotifierProvider<AdminUsersViewModel, List<AdminUser>>(
  AdminUsersViewModel.new,
);
