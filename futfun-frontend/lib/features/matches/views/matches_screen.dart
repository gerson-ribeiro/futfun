import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_bar_actions.dart';
import '../../../core/providers/active_competition_provider.dart';
import '../viewmodels/matches_viewmodel.dart';
import 'widgets/match_card.dart';

/// true = mais recentes primeiro (newest→oldest); false = padrão (oldest→newest)
final matchesSortDescendingProvider = StateProvider<bool>((ref) => false);

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeCompetitionNotifierProvider);

    return activeAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Jogos')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Jogos')),
        body: Center(child: Text('Erro: $err')),
      ),
      data: (state) {
        if (state.selected == null) {
          return Scaffold(
            appBar: _buildAppBar(context, ref, null),
            body: const Center(
              child: Text('Selecione um campeonato na barra lateral.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        return Scaffold(
          appBar: _buildAppBar(context, ref, null),
          body: _MatchesBody(competitionCode: state.selected!.code),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, WidgetRef ref, Widget? bottom) {
    return AppBar(
      title: const Text('Jogos'),
      leading: buildLeadingWidget(context, ref),
      actions: _buildActions(context, ref),
      bottom: bottom as PreferredSizeWidget?,
    );
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref) {
    final descending = ref.watch(matchesSortDescendingProvider);
    return [
      IconButton(
        icon: Icon(descending ? Icons.arrow_upward : Icons.arrow_downward),
        tooltip: descending ? 'Mais antigos primeiro' : 'Mais recentes primeiro',
        onPressed: () => ref.read(matchesSortDescendingProvider.notifier).state = !descending,
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        tooltip: 'Campeonatos',
        onPressed: () => context.push('/settings/competitions'),
      ),
      ...buildAppBarActions(context, ref),
    ];
  }
}

class _MatchesBody extends ConsumerWidget {
  final String competitionCode;
  const _MatchesBody({required this.competitionCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(matchesViewModelProvider(competitionCode));

    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text(
              'Erro ao carregar jogos',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(matchesViewModelProvider(competitionCode).notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
      data: (matchesState) {
        if (matchesState.matches.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum jogo disponível',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          );
        }

        final descending = ref.watch(matchesSortDescendingProvider);
        final groups = _groupMatchesByDate(matchesState, descending: descending);

        // When descending: LoadMore at index 0, groups at 1..n
        // When ascending:  groups at 0..n-1, LoadMore at n (default)
        return RefreshIndicator(
          onRefresh: () => ref.read(matchesViewModelProvider(competitionCode).notifier).refresh(),
          child: ListView.builder(
            padding: EdgeInsets.only(top: descending ? 0 : 0, bottom: 16),
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (descending) {
                // LoadMore at top (index 0), then groups
                if (index == 0) {
                  return _LoadMoreFooter(
                    competitionCode: competitionCode,
                    isLoading: matchesState.isLoadingMore,
                    hasReachedEnd: matchesState.hasReachedEnd,
                  );
                }
                final group = groups[index - 1];
                return _MatchGroupWidget(
                  group: group,
                  matchesState: matchesState,
                  competitionCode: competitionCode,
                );
              } else {
                // Groups first, LoadMore at bottom
                if (index == groups.length) {
                  return _LoadMoreFooter(
                    competitionCode: competitionCode,
                    isLoading: matchesState.isLoadingMore,
                    hasReachedEnd: matchesState.hasReachedEnd,
                  );
                }
                final group = groups[index];
                return _MatchGroupWidget(
                  group: group,
                  matchesState: matchesState,
                  competitionCode: competitionCode,
                );
              }
            },
          ),
        );
      },
    );
  }

  /// Groups matches by calendar date (local time).
  /// [descending] = true → newest first (most recent date at top).
  List<_MatchGroup> _groupMatchesByDate(MatchesState matchesState, {bool descending = false}) {
    final matches = matchesState.matches;
    final groups = <String, _MatchGroup>{};
    final today = DateTime.now();
    final todayKey = _dayKey(today);
    final tomorrowKey = _dayKey(today.add(const Duration(days: 1)));

    for (final m in matches) {
      final local = m.kickoffTime.toLocal();
      final key = _dayKey(local);

      String label;
      if (key == todayKey) {
        label = 'Hoje · ${DateFormat('dd/MM').format(local)}';
      } else if (key == tomorrowKey) {
        label = 'Amanhã · ${DateFormat('dd/MM').format(local)}';
      } else {
        label = DateFormat('EEEE · dd/MM', 'pt_BR').format(local);
      }

      groups.putIfAbsent(key, () => _MatchGroup(label: label, matchIds: []));
      groups[key]!.matchIds.add(m.id);
    }

    final sorted = groups.entries.toList()
      ..sort((a, b) => descending
          ? b.key.compareTo(a.key)
          : a.key.compareTo(b.key));

    return sorted.map((e) => e.value).toList();
  }

  String _dayKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _MatchGroupWidget extends StatelessWidget {
  final _MatchGroup group;
  final MatchesState matchesState;
  final String competitionCode;

  const _MatchGroupWidget({
    required this.group,
    required this.matchesState,
    required this.competitionCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            group.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...group.matchIds.map((id) {
          final match = matchesState.matches.firstWhere((m) => m.id == id);
          return MatchCard(
            key: ValueKey(match.id),
            match: match,
            competitionCode: competitionCode,
          );
        }),
      ],
    );
  }
}

class _LoadMoreFooter extends ConsumerWidget {
  final String competitionCode;
  final bool isLoading;
  final bool hasReachedEnd;

  const _LoadMoreFooter({
    required this.competitionCode,
    required this.isLoading,
    required this.hasReachedEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasReachedEnd) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Sem mais jogos disponíveis',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: () =>
              ref.read(matchesViewModelProvider(competitionCode).notifier).loadMore(),
          icon: const Icon(Icons.expand_more),
          label: const Text('Ver mais jogos'),
        ),
      ),
    );
  }
}

class _MatchGroup {
  final String label;
  final List<String> matchIds;
  _MatchGroup({required this.label, required this.matchIds});
}
