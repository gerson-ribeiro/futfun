// lib/features/admin/views/admin_users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/admin_users_viewmodel.dart';
import '../data/models/admin_user_model.dart';
import '../../../features/auth/data/models/auth_user.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_bar_actions.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuários'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: buildLeadingWidget(context, ref),
        actions: buildAppBarActions(context, ref),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (users) {
          final pending = users.where((u) => u.role == UserRole.pending).toList();
          final members = users.where((u) => u.role == UserRole.member).toList();
          final admins = users.where((u) => u.role == UserRole.admin).toList();

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  labelColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Pendentes (${pending.length})'),
                    Tab(text: 'Membros (${members.length})'),
                    Tab(text: 'Admins (${admins.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _UserList(users: pending, showApprove: true, ref: ref),
                      _UserList(users: members, showPromote: true, ref: ref),
                      _UserList(users: admins, showDemote: true, ref: ref),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<AdminUser> users;
  final WidgetRef ref;
  final bool showApprove;
  final bool showPromote;
  final bool showDemote;

  const _UserList({
    required this.users,
    required this.ref,
    this.showApprove = false,
    this.showPromote = false,
    this.showDemote = false,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('Nenhum usuário'));
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Text(
              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(user.displayName),
          subtitle: Text('${user.email} • ${user.provider}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showApprove)
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Aprovar',
                  onPressed: () => _handleAction(
                    context,
                    () => ref
                        .read(adminUsersViewModelProvider.notifier)
                        .approveUser(user.id),
                  ),
                ),
              if (showPromote)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                  tooltip: 'Promover a Admin',
                  onPressed: () => _handleAction(
                    context,
                    () => ref
                        .read(adminUsersViewModelProvider.notifier)
                        .promoteToAdmin(user.id),
                  ),
                ),
              if (showDemote)
                IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.orange),
                  tooltip: 'Remover acesso Admin',
                  onPressed: () => _confirmDemote(context, user),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Remover',
                onPressed: () => _confirmDelete(context, user),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleAction(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, AdminUser user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover usuário'),
        content: Text('Tem certeza que deseja remover ${user.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleAction(
                context,
                () => ref.read(adminUsersViewModelProvider.notifier).removeUser(user.id),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _confirmDemote(BuildContext context, AdminUser user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover acesso Admin'),
        content: Text(
          'Tem certeza que deseja remover o acesso de Admin de ${user.displayName}? '
          'O usuário continuará como Membro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleAction(
                context,
                () => ref.read(adminUsersViewModelProvider.notifier).demoteToMember(user.id),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Remover Admin'),
          ),
        ],
      ),
    );
  }
}
