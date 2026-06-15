import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_bar_actions.dart';
import '../../../features/auth/viewmodels/auth_viewmodel.dart';
import '../data/models/ranking_entry.dart';
import '../viewmodels/ranking_viewmodel.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(rankingViewModelProvider);
    final authState = ref.watch(authViewModelProvider);
    final currentUserId = authState.valueOrNull?.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking'),
        leading: buildLeadingWidget(context, ref),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(rankingViewModelProvider.notifier).refresh(),
          ),
          ...buildAppBarActions(context, ref),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Erro ao carregar ranking',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(rankingViewModelProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (rankingState) {
          final leaderboard = rankingState.leaderboard;
          final myRanking = rankingState.myRanking;

          if (leaderboard.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(rankingViewModelProvider.notifier).refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 64, color: Color(0xFFBDBDBD)),
                        SizedBox(height: 16),
                        Text(
                          'Ranking ainda não começou',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'O ranking será atualizado após a primeira partida encerrada com placar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Color(0xFF757575)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final userVisibleInList = currentUserId != null &&
              leaderboard.any((e) => e.userId == currentUserId);

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => ref.read(rankingViewModelProvider.notifier).refresh(),
                child: ListView(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: (!userVisibleInList && myRanking != null) ? 72 : 16,
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Text(
                        'CLASSIFICAÇÃO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...leaderboard.map(
                      (entry) => _RankingRow(
                        entry: entry,
                        isCurrentUser: entry.userId == currentUserId,
                      ),
                    ),
                  ],
                ),
              ),
              // Pinned footer: current user's row when not visible in the list
              if (!userVisibleInList && myRanking != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: _RankingRow(
                      entry: myRanking,
                      isCurrentUser: true,
                      compact: true,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final RankingEntry entry;
  final bool isCurrentUser;
  final bool compact;

  const _RankingRow({
    required this.entry,
    this.isCurrentUser = false,
    this.compact = false,
  });

  static String _medal(int pos) {
    if (pos == 1) return '🥇';
    if (pos == 2) return '🥈';
    if (pos == 3) return '🥉';
    return '';
  }

  static Color _borderColor(int pos) {
    if (pos == 1) return const Color(0xFFFFD700);
    if (pos == 2) return const Color(0xFFB0BEC5);
    if (pos == 3) return const Color(0xFFBF8C60);
    return Colors.grey.shade200;
  }

  static List<Color> _gradientColors(int pos) {
    if (pos == 1) return [const Color(0xFFFFFDE7), Colors.white];
    if (pos == 2) return [const Color(0xFFF5F5F5), Colors.white];
    if (pos == 3) return [const Color(0xFFFBE9E7), Colors.white];
    return [Colors.transparent, Colors.transparent];
  }

  @override
  Widget build(BuildContext context) {
    final medal = _medal(entry.position);
    final isTop3 = entry.position <= 3;
    final borderColor = isCurrentUser
        ? AppColors.success.withOpacity(0.4)
        : _borderColor(entry.position);
    final gradColors = isCurrentUser
        ? [AppColors.success.withOpacity(0.08), AppColors.success.withOpacity(0.04)]
        : _gradientColors(entry.position);
    final ptsColor = isCurrentUser
        ? AppColors.success
        : (entry.position == 1
            ? const Color(0xFFB8860B)
            : entry.position == 2
                ? const Color(0xFF546E7A)
                : entry.position == 3
                    ? const Color(0xFF6D4C41)
                    : Theme.of(context).colorScheme.onSurface);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        gradient: isTop3 || isCurrentUser
            ? LinearGradient(
                colors: gradColors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: (!isTop3 && !isCurrentUser)
            ? Theme.of(context).colorScheme.surface
            : null,
        borderRadius: BorderRadius.circular(10),
        border: isCurrentUser
            ? Border.all(color: borderColor, width: 1.5)
            : (isTop3
                ? Border(
                    left: BorderSide(color: borderColor, width: 5),
                    top: BorderSide(color: Colors.grey.shade100),
                    right: BorderSide(color: Colors.grey.shade100),
                    bottom: BorderSide(color: Colors.grey.shade100),
                  )
                : Border.all(color: Colors.grey.shade200)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Posição / Medalha
            SizedBox(
              width: 36,
              child: medal.isNotEmpty
                  ? Text(medal, style: const TextStyle(fontSize: 20))
                  : Text(
                      '${entry.position}°',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCurrentUser
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
            ),
            // Nome + contagem de palpites
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName + (isCurrentUser ? ' (você)' : ''),
                    style: TextStyle(
                      fontSize: isTop3 ? 15 : 14,
                      fontWeight: isTop3
                          ? FontWeight.w700
                          : (isCurrentUser ? FontWeight.w700 : FontWeight.w500),
                      color: isCurrentUser
                          ? AppColors.success
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!compact)
                    Text(
                      '${entry.matchesPredicted} palpites',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // Acertos (só quando não compacto)
            if (!compact) ...[
              Text(
                '${entry.exactScores}✓✓ ${entry.correctResults}✓',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
            ],
            // Pontos
            Text(
              '${entry.totalPoints} pts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: ptsColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
