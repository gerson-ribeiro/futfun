import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';

Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sair'),
      content: const Text('Deseja mesmo sair do FutFun?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await ref.read(authViewModelProvider.notifier).logout();
  }
}
