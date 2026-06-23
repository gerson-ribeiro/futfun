import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../data/models/match_prediction_item.dart';
import '../viewmodels/match_predictions_viewmodel.dart';

class MatchPredictionsScreen extends ConsumerWidget {
  final int matchExternalId;
  final String homeTeam;
  final String awayTeam;
  final String matchStatus;
  final int? homeScore;
  final int? awayScore;

  const MatchPredictionsScreen({
    super.key,
    required this.matchExternalId,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchStatus,
    this.homeScore,
    this.awayScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(matchPredictionsProvider(matchExternalId));
    final isFinished = matchStatus == 'FINISHED';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$homeTeam × $awayTeam',
          style: const TextStyle(fontSize: 15),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(matchPredictionsProvider(matchExternalId).notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _MatchHeader(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            matchStatus: matchStatus,
            homeScore: homeScore,
            awayScore: awayScore,
          ),
          Expanded(
            child: asyncState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('Erro ao carregar palpites'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref
                          .read(matchPredictionsProvider(matchExternalId).notifier)
                          .refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_soccer, size: 64, color: AppColors.textSecondary),
                        SizedBox(height: 16),
                        Text(
                          'Nenhum palpite para este jogo',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _PredictionTile(
                    item: items[index],
                    position: index + 1,
                    isFinished: isFinished,
                    homeScore: homeScore,
                    awayScore: awayScore,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final String matchStatus;
  final int? homeScore;
  final int? awayScore;

  const _MatchHeader({
    required this.homeTeam,
    required this.awayTeam,
    required this.matchStatus,
    this.homeScore,
    this.awayScore,
  });

  @override
  Widget build(BuildContext context) {
    final isFinished = matchStatus == 'FINISHED';
    final isLive = matchStatus == 'LIVE' || matchStatus == 'IN_PLAY' || matchStatus == 'PAUSED';

    Color badgeBg;
    Color badgeFg;
    String badgeLabel;
    if (isLive) {
      badgeBg = Colors.red.shade100;
      badgeFg = Colors.red.shade800;
      badgeLabel = 'AO VIVO';
    } else if (isFinished) {
      badgeBg = Colors.grey.shade200;
      badgeFg = AppColors.textSecondary;
      badgeLabel = 'Encerrado';
    } else {
      badgeBg = Colors.blue.shade50;
      badgeFg = AppColors.primary;
      badgeLabel = 'Aguardando';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isFinished && homeScore != null && awayScore != null) ...[
            Text(
              '$homeScore — $awayScore',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(fontSize: 11, color: badgeFg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionTile extends StatelessWidget {
  final MatchPredictionItem item;
  final int position;
  final bool isFinished;
  final int? homeScore;
  final int? awayScore;

  const _PredictionTile({
    required this.item,
    required this.position,
    required this.isFinished,
    this.homeScore,
    this.awayScore,
  });

  List<_BreakdownItem> _buildBreakdown() {
    final ph = item.predictedHome;
    final pa = item.predictedAway;
    final sh = homeScore ?? 0;
    final sa = awayScore ?? 0;

    int sign(int v) => v > 0 ? 1 : (v < 0 ? -1 : 0);
    final resultCorrect = sign(ph - pa) == sign(sh - sa);
    final homeCorrect = ph == sh;
    final awayCorrect = pa == sa;

    if (!resultCorrect) {
      return [_BreakdownItem(ok: false, label: 'Resultado errado', pts: 0)];
    }
    if (homeCorrect && awayCorrect) {
      return [_BreakdownItem(ok: true, label: 'Placar exato! ($ph × $pa)', pts: 10)];
    }
    return [
      _BreakdownItem(ok: true, label: 'Resultado certo', pts: 5),
      if (homeCorrect)
        _BreakdownItem(ok: true, label: 'Placar do mandante correto ($ph)', pts: 2)
      else if (awayCorrect)
        _BreakdownItem(ok: true, label: 'Placar do visitante correto ($pa)', pts: 2),
      if (!homeCorrect)
        _BreakdownItem(ok: false, label: 'Placar do mandante errado ($ph ≠ $sh)', pts: 0),
      if (!awayCorrect)
        _BreakdownItem(ok: false, label: 'Placar do visitante errado ($pa ≠ $sa)', pts: 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pts = item.points;

    Color? ptsColor;
    if (pts != null) {
      if (pts >= 10) ptsColor = AppColors.success;
      else if (pts >= 5) ptsColor = Colors.orange;
      else ptsColor = AppColors.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      color: item.isCurrentUser ? AppColors.primary.withOpacity(0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: item.isCurrentUser
            ? BorderSide(color: AppColors.primary.withOpacity(0.3))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isFinished)
                  SizedBox(
                    width: 22,
                    child: Text(
                      '$position°',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: item.isCurrentUser
                      ? AppColors.primary
                      : Colors.grey.shade300,
                  child: Text(
                    item.displayName.isNotEmpty
                        ? item.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: item.isCurrentUser ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.displayName,
                              style: TextStyle(
                                fontWeight: item.isCurrentUser
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isCurrentUser) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Você',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Palpite: ${item.predictedHome} × ${item.predictedAway}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (pts != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ptsColor?.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: ptsColor ?? AppColors.textSecondary),
                    ),
                    child: Text(
                      pts > 0 ? '+$pts pts' : '0 pts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ptsColor,
                      ),
                    ),
                  ),
              ],
            ),
            if (isFinished && homeScore != null && awayScore != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildBreakdown()
                      .map((b) => _BreakdownRow(item: b))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreakdownItem {
  final bool ok;
  final String label;
  final int pts;
  const _BreakdownItem({required this.ok, required this.label, required this.pts});
}

class _BreakdownRow extends StatelessWidget {
  final _BreakdownItem item;
  const _BreakdownRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(item.ok ? '✅' : '❌', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                color: item.ok
                    ? const Color(0xFF424242)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            item.pts > 0 ? '+${item.pts}' : '+0',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: item.ok && item.pts > 0
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
