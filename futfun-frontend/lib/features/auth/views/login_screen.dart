// lib/features/auth/views/login_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/utils/web_redirect_stub.dart'
    if (dart.library.html) '../../../core/utils/web_redirect_web.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: _loginContent(context, ref, authState),
          ),
          Positioned(
            top: 48,
            right: 16,
            child: IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              tooltip: isDark ? 'Tema claro' : 'Tema escuro',
              onPressed: () {
                ref.read(themeModeProvider.notifier).state =
                    isDark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginContent(BuildContext context, WidgetRef ref, AsyncValue<AuthState> authState) {
    final buttons = authState.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, _) => Column(
        children: [
          Text('Erro: $err', style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 16),
          _buildLoginButtons(context, ref),
        ],
      ),
      data: (_) => _buildLoginButtons(context, ref),
    );

    final content = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_soccer, size: 80, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            AppStrings.appName,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.appTitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          buttons,
        ],
      ),
    );

    if (kIsWeb) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildLoginButtons(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _OAuthButton(
          provider: 'google',
          label: 'Entrar com Google',
          icon: const Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          ref: ref,
        ),
        const SizedBox(height: 12),
        _OAuthButton(
          provider: 'microsoft',
          label: 'Entrar com Microsoft',
          icon: const Icon(Icons.window, color: Colors.white),
          ref: ref,
        ),
      ],
    );
  }
}

class _OAuthButton extends StatefulWidget {
  final String provider;
  final String label;
  final Widget icon;
  final WidgetRef ref;

  const _OAuthButton({
    required this.provider,
    required this.label,
    required this.icon,
    required this.ref,
  });

  @override
  State<_OAuthButton> createState() => _OAuthButtonState();
}

class _OAuthButtonState extends State<_OAuthButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : () => _handlePress(context),
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : widget.icon,
        label: Text(_loading ? 'Aguarde...' : widget.label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }

  Future<void> _handlePress(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final state = kIsWeb ? 'web' : '';
      final url = await widget.ref.read(authViewModelProvider.notifier).getLoginUrl(widget.provider, state: state);
      if (kIsWeb) {
        // Redirect the current tab — after OAuth the provider redirects back
        // to /#/auth/callback?... in this same tab, avoiding a stale login tab.
        redirectCurrentPage(url);
      } else {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e, stackTrace) {
      debugPrint('[Auth] Erro ao obter URL de login para "${widget.provider}": $e');
      debugPrint('[Auth] StackTrace: $stackTrace');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
