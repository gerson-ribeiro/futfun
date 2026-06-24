import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/active_competition_provider.dart';
import '../data/models/user_prediction_item.dart';
import '../viewmodels/user_predictions_viewmodel.dart';

class UserPredictionsScreen extends ConsumerWidget {
  final String userId;
  final String displayName;

  const UserPredictionsScreen({
    super.key,
    required this.userId,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compCode = ref.watch(activeCompetitionNotifierProvider)
            .valueOrNull
            ?.selected
            ?.code ??
        '';

    if (compCode.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(displayName),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final arg = (userId: userId, competitionCode: compCode);
    final asyncState = ref.watch(userPredictionsProvider(arg));

    return Scaffold(
      appBar: _buildAppBar(
        asyncState.valueOrNull?.displayName ?? displayName,
        onRefresh: () => ref.read(userPredictionsProvider(arg).notifier).refresh(),
      ),
      body: asyncState.when(
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
                onPressed: () =>
                    ref.read(userPredictionsProvider(arg).notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (state) {
          if (state.predictions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_soccer, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum palpite encerrado neste campeonato',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemCount: state.predictions.length,
            itemBuilder: (context, index) =>
                _PredictionTile(item: state.predictions[index]),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(String name, {VoidCallback? onRefresh}) {
    return AppBar(
      title: Text(name, style: const TextStyle(fontSize: 16)),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      actions: [
        if (onRefresh != null)
          IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh),
      ],
    );
  }
}

class _PredictionTile extends StatelessWidget {
  final UserPredictionItem item;

  const _PredictionTile({required this.item});

  List<_BreakdownItem> _buildBreakdown() {
    final ph = item.predictedHome;
    final pa = item.predictedAway;
    final sh = item.matchScoreHome ?? 0;
    final sa = item.matchScoreAway ?? 0;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM HH:mm').format(item.kickoffTime.toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (pts != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: ptsColor?.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ptsColor ?? AppColors.textSecondary),
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
            const SizedBox(height: 6),
            // Teams + scores
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    item.matchHomeTeam,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${item.matchScoreHome ?? 0} - ${item.matchScoreAway ?? 0}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.matchAwayTeam,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Prediction row
            Row(
              children: [
                const Icon(Icons.sports_soccer, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Text(
                  'Palpite:',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    border: Border.all(color: const Color(0xFFF57C00)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.predictedHome} × ${item.predictedAway}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
            // Breakdown
            if (item.matchScoreHome != null && item.matchScoreAway != null) ...[
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
                color: item.ok ? const Color(0xFF424242) : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            item.pts > 0 ? '+${item.pts}' : '+0',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: item.ok && item.pts > 0 ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
