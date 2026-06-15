import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_bar_actions.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'widgets/points_line_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(dashboardViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Dashboard'),
        leading: buildLeadingWidget(context, ref),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dashboardViewModelProvider.notifier).refresh(),
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
              const Text('Erro ao carregar dashboard',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(dashboardViewModelProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (dashState) {
          final myRanking = dashState.myRanking;
          final history = dashState.history;

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(dashboardViewModelProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Stats card
                if (myRanking != null) ...[
                  _StatsCard(
                    position: myRanking.position,
                    totalPoints: myRanking.totalPoints,
                    exactScores: myRanking.exactScores,
                    correctResults: myRanking.correctResults,
                    matchesPredicted: myRanking.matchesPredicted,
                  ),
                  const SizedBox(height: 16),
                ],
                // Chart section
                const Text(
                  'EVOLUÇÃO DE PONTOS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                    child: PointsLineChart(history: history),
                  ),
                ),
                const SizedBox(height: 16),
                // History list
                if (history.isNotEmpty) ...[
                  const Text(
                    'HISTÓRICO POR RODADA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...history.map((entry) => _HistoryRow(entry: entry)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int position;
  final int totalPoints;
  final int exactScores;
  final int correctResults;
  final int matchesPredicted;

  const _StatsCard({
    required this.position,
    required this.totalPoints,
    required this.exactScores,
    required this.correctResults,
    required this.matchesPredicted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Minhas Estatísticas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$position° lugar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatItem(label: 'Pontos', value: '$totalPoints'),
                _StatItem(label: 'Placar exato', value: '$exactScores'),
                _StatItem(label: 'Resultado', value: '$correctResults'),
                _StatItem(label: 'Palpites', value: '$matchesPredicted'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final dynamic entry;
  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry as dynamic;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.roundStage as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: null,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format((e.snapshotAt as DateTime).toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${e.totalPoints} pts',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: null,
                ),
              ),
              Text(
                '+${e.pointsEarned} nesta rodada',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
