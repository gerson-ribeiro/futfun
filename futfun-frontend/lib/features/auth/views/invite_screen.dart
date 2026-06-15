// lib/features/auth/views/invite_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/auth_repository.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';

final _inviteValidationProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, token) async {
    final repo = AuthRepository(DioClient().dio);
    return repo.validateInvite(token);
  },
);

class InviteScreen extends ConsumerWidget {
  final String token;

  const InviteScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteAsync = ref.watch(_inviteValidationProvider(token));

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: inviteAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Convite inválido ou expirado',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.error,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            data: (invite) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_soccer, size: 72, color: AppColors.primary),
                const SizedBox(height: 24),
                Text(
                  'Você foi convidado!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entre para participar do FutFun — bolão da Copa do Mundo 2026.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _InviteOAuthButton(
                  provider: 'google',
                  label: 'Entrar com Google',
                  inviteToken: token,
                  ref: ref,
                ),
                const SizedBox(height: 12),
                _InviteOAuthButton(
                  provider: 'microsoft',
                  label: 'Entrar com Microsoft',
                  inviteToken: token,
                  ref: ref,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteOAuthButton extends StatelessWidget {
  final String provider;
  final String label;
  final String inviteToken;
  final WidgetRef ref;

  const _InviteOAuthButton({
    required this.provider,
    required this.label,
    required this.inviteToken,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final oauthState = 'invite:$inviteToken';
          final url = await ref
              .read(authViewModelProvider.notifier)
              .getLoginUrl(provider, state: oauthState);
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: Text(label),
      ),
    );
  }
}
