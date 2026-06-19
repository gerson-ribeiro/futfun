// lib/features/auth/views/pending_approval_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/constants/app_colors.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'Aguardando aprovação',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Seu cadastro está em análise. Você receberá um email assim que o acesso for aprovado.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => ref.read(authViewModelProvider.notifier).checkApprovalStatus(),
                child: const Text('Verificar aprovação'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
