// lib/features/admin/viewmodels/admin_invites_viewmodel.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';
import '../data/models/invite_model.dart';
import '../../../core/network/dio_client.dart';

class AdminInvitesViewModel extends AsyncNotifier<List<InviteModel>> {
  final _repository = AdminRepository(DioClient().dio);

  @override
  Future<List<InviteModel>> build() async {
    return _repository.getInvites();
  }

  Future<({String inviteUrl, bool emailSent})> sendInvite(String email) async {
    final result = await _repository.sendInvite(email);
    ref.invalidateSelf();
    return result;
  }

  Future<void> cancelInvite(String inviteId) async {
    await _repository.cancelInvite(inviteId);
    ref.invalidateSelf();
  }

  Future<({String inviteUrl, bool emailSent})> resendInvite(String inviteId) async {
    final result = await _repository.resendInvite(inviteId);
    ref.invalidateSelf();
    return result;
  }
}

final adminInvitesViewModelProvider =
    AsyncNotifierProvider<AdminInvitesViewModel, List<InviteModel>>(
  AdminInvitesViewModel.new,
);
