// lib/core/router/app_router.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shell_scaffold_key_provider.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart' show authViewModelProvider, AuthStage;
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/pending_approval_screen.dart';
import '../../features/auth/views/invite_screen.dart';
import '../../features/matches/views/matches_screen.dart';
import '../../features/ranking/views/ranking_screen.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/admin/views/admin_shell.dart';
import '../../features/admin/views/admin_users_screen.dart';
import '../../features/admin/views/admin_invites_screen.dart';
import '../../features/competitions/views/competition_settings_screen.dart';
import '../../features/competitions/views/admin_competitions_screen.dart';
import '../../features/predictions/views/predictions_screen.dart';
import '../constants/app_colors.dart';
import '../providers/active_competition_provider.dart';
import '../../features/competitions/data/models/competition_model.dart';

class _AppShell extends ConsumerWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isAdmin = ref.watch(authViewModelProvider)
            .whenData((s) => s.stage == AuthStage.admin)
            .valueOrNull ??
        false;

    int currentIndex = 0;
    if (location.startsWith('/ranking')) currentIndex = 1;
    if (location.startsWith('/dashboard')) currentIndex = 2;
    if (location.startsWith('/predictions')) currentIndex = 3;

    // Nav destinations — shared between Rail and BottomNav
    final navItems = [
      (icon: Icons.sports_soccer, label: 'Jogos', route: '/matches'),
      (icon: Icons.leaderboard, label: 'Ranking', route: '/ranking'),
      (icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
      (icon: Icons.checklist, label: 'Palpites', route: '/predictions'),
      if (isAdmin)
        (icon: Icons.admin_panel_settings, label: 'Admin', route: '/admin/users'),
    ];

    void navigate(int i) => context.go(navItems[i].route);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWideWeb = kIsWeb && screenWidth >= 600;
    final isMobileWeb = kIsWeb && screenWidth < 600;

    // ── Desktop web: NavigationRail permanente ─────────────────────────────
    if (isWideWeb) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: navigate,
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              indicatorColor: AppColors.primary.withOpacity(0.12),
              leading: Consumer(
                builder: (ctx, ref, _) {
                  final compAsync = ref.watch(activeCompetitionNotifierProvider);
                  final available = compAsync.valueOrNull?.available ?? [];
                  final selected = compAsync.valueOrNull?.selected;
                  return Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Icon(Icons.sports_soccer, color: AppColors.primary, size: 28),
                      ),
                      if (available.length > 1)
                        PopupMenuButton<CompetitionModel>(
                          icon: const Icon(Icons.emoji_events, color: AppColors.primary),
                          tooltip: selected?.name ?? 'Campeonato',
                          onSelected: (comp) => ref.read(activeCompetitionNotifierProvider.notifier).select(comp),
                          itemBuilder: (ctx) => available
                              .map((c) => PopupMenuItem(value: c, child: Text(c.name)))
                              .toList(),
                        ),
                    ],
                  );
                },
              ),
              destinations: navItems
                  .map((d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Mobile (web e nativo): Drawer com hambúrguer ──────────────────────
    final scaffoldKey = ref.read(shellScaffoldKeyProvider);
    return Scaffold(
      key: scaffoldKey,
      drawer: _NavDrawer(
        currentIndex: currentIndex,
        navItems: navItems,
        onNavigate: (i) {
          scaffoldKey.currentState?.closeDrawer();
          navigate(i);
        },
      ),
      body: child,
    );
  }
}

class _NavDrawer extends ConsumerWidget {
  final int currentIndex;
  final List<({IconData icon, String label, String route})> navItems;
  final void Function(int) onNavigate;

  const _NavDrawer({
    required this.currentIndex,
    required this.navItems,
    required this.onNavigate,
  });

  Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionAsync = ref.watch(activeCompetitionNotifierProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.sports_soccer, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'FutFun',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            // ── Campeonato ───────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'CAMPEONATO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1),
              ),
            ),
            ...competitionAsync.when(
              data: (state) => state.available.map((comp) {
                final isActive = state.selected?.code == comp.code;
                final color = _colorFromHex(comp.color) ?? AppColors.primary;
                return ListTile(
                  leading: Icon(Icons.emoji_events, color: isActive ? color : AppColors.textSecondary),
                  title: Text(
                    comp.name,
                    style: TextStyle(color: isActive ? color : null, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal),
                  ),
                  selected: isActive,
                  selectedTileColor: color.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    ref.read(activeCompetitionNotifierProvider.notifier).select(comp);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
              loading: () => [const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))],
              error: (_, __) => [const SizedBox()],
            ),
            const Divider(),
            // ── Navegação ────────────────────────────────────────
            ...navItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final selected = i == currentIndex;
              return ListTile(
                leading: Icon(item.icon, color: selected ? AppColors.primary : null),
                title: Text(
                  item.label,
                  style: TextStyle(color: selected ? AppColors.primary : null, fontWeight: selected ? FontWeight.w700 : FontWeight.normal),
                ),
                selected: selected,
                selectedTileColor: AppColors.primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () => onNavigate(i),
              );
            }),
          ],
        ),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authStateAsync = ref.read(authViewModelProvider);
      return authStateAsync.when(
        loading: () => null,
        error: (_, __) => '/login',
        data: (authState) {
          final loc = state.matchedLocation;

          // Allow public routes always
          if (loc.startsWith('/invite') || loc == '/login') return null;

          const authTransient = {'/login', '/auth/callback'};

          switch (authState.stage) {
            case AuthStage.unauthenticated:
              // Mantém em /auth/callback enquanto processa o OAuth (tokens ainda não salvos)
              if (loc == '/auth/callback') return null;
              return '/login';
            case AuthStage.pending:
              return loc == '/pending' ? null : '/pending';
            case AuthStage.member:
              if (authTransient.contains(loc) || loc == '/pending') return '/matches';
              if (loc.startsWith('/admin')) return '/matches';
              return null;
            case AuthStage.admin:
              if (authTransient.contains(loc) || loc == '/pending') return '/admin/users';
              return null;
          }
        },
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/pending', builder: (_, __) => const PendingApprovalScreen()),
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) => _AuthCallbackScreen(params: state.uri.queryParameters),
      ),
      GoRoute(
        path: '/invite',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return InviteScreen(token: token);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/matches', builder: (_, __) => const MatchesScreen()),
          GoRoute(path: '/ranking', builder: (_, __) => const RankingScreen()),
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/predictions', builder: (_, __) => const PredictionsScreen()),
          GoRoute(
            path: '/settings/competitions',
            builder: (_, __) => const CompetitionSettingsScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
          GoRoute(path: '/admin/invites', builder: (_, __) => const AdminInvitesScreen()),
          GoRoute(
            path: '/admin/competitions',
            builder: (_, __) => const AdminCompetitionsScreen(),
          ),
        ],
      ),
    ],
  );
  return router;
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._ref) {
    _ref.listen(authViewModelProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

// Processa o callback OAuth na web — recebe tokens via query params e autentica
class _AuthCallbackScreen extends ConsumerStatefulWidget {
  final Map<String, String> params;
  const _AuthCallbackScreen({required this.params});

  @override
  ConsumerState<_AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<_AuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    // Adia para após o frame: modificar provider durante build é proibido pelo Riverpod
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallback());
  }

  Future<void> _handleCallback() async {
    final accessToken = widget.params['accessToken'];
    final refreshToken = widget.params['refreshToken'];
    final error = widget.params['error'];

    if (error != null || accessToken == null || refreshToken == null) {
      debugPrint('[AuthCallback] Parâmetros inválidos: error=$error, hasToken=${accessToken != null}');
      ref.read(routerProvider).go('/login');
      return;
    }

    try {
      await ref.read(authViewModelProvider.notifier).handleDeepLinkCallback(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: {
          'id': widget.params['userId'] ?? '',
          'email': widget.params['email'] ?? '',
          'displayName': widget.params['displayName'] ?? '',
          'role': widget.params['role'] ?? 'PENDING',
        },
      );
      // Router redireciona automaticamente via refreshListenable após estado mudar
    } catch (e, st) {
      debugPrint('[AuthCallback] Erro ao processar callback: $e\n$st');
      if (mounted) ref.read(routerProvider).go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
