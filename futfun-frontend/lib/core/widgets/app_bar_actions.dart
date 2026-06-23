import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shell_scaffold_key_provider.dart';
import '../providers/theme_provider.dart';
import 'logout_helper.dart';
import 'diagnostic_screen.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';

/// Returns a hamburger [IconButton] to open the side drawer on mobile
/// (web and native) or null on wide desktop web.
Widget? buildLeadingWidget(BuildContext context, WidgetRef ref) {
  final isWideWeb = kIsWeb && MediaQuery.sizeOf(context).width >= 600;
  if (isWideWeb) return null;
  return IconButton(
    icon: const Icon(Icons.menu),
    tooltip: 'Menu',
    onPressed: () =>
        ref.read(shellScaffoldKeyProvider).currentState?.openDrawer(),
  );
}

/// Standard top-bar actions: theme toggle + logout confirmation.
/// Add to every authenticated screen's [AppBar.actions].
List<Widget> buildAppBarActions(BuildContext context, WidgetRef ref) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isAdmin = ref.watch(authViewModelProvider)
      .whenData((s) => s.stage == AuthStage.admin)
      .valueOrNull ?? false;

  return [
    IconButton(
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      tooltip: isDark ? 'Tema claro' : 'Tema escuro',
      onPressed: () {
        ref.read(themeModeProvider.notifier).state =
            isDark ? ThemeMode.light : ThemeMode.dark;
      },
    ),
    IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Sair',
      onPressed: () => confirmLogout(context, ref),
    ),
    if (isAdmin)
      IconButton(
        icon: const Icon(Icons.bug_report_outlined),
        tooltip: 'Diagnóstico',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DiagnosticScreen()),
        ),
      ),
  ];
}
