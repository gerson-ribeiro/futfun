import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_bar_actions.dart';
import '../../../core/widgets/team_crest.dart';
import '../data/models/prediction_with_match.dart';
import '../viewmodels/predictions_viewmodel.dart';

// 'all' | 'scheduled' | 'finished'
final _predFilterProvider = StateProvider<String>((ref) => 'all');

Future<void> _showEditDialog(
  BuildContext context,
  WidgetRef ref,
  PredictionWithMatch prediction,
) async {
  int home = prediction.predictedHome;
  int away = prediction.predictedAway;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(
          '${prediction.match.homeTeamShort ?? prediction.match.homeTeamName} vs ${prediction.match.awayTeamShort ?? prediction.match.awayTeamName}',
          style: const TextStyle(fontSize: 15),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ScoreButton(
              value: home,
              onChanged: (v) => setState(() => home = v),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('×', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            _ScoreButton(
              value: away,
              onChanged: (v) => setState(() => away = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(predictionsViewModelProvider.notifier)
                    .updatePrediction(prediction.matchId, home, away);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro ao atualizar palpite'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

class _ScoreButton extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _ScoreButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.expand_less),
          onPressed: () => onChanged(value + 1),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.expand_more),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
      ],
    );
  }
}

class PredictionsScreen extends ConsumerWidget {
  const PredictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(predictionsViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Palpites'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: buildLeadingWidget(context, ref),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(predictionsViewModelProvider.notifier).refresh(),
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
              const Text('Erro ao carregar palpites',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(predictionsViewModelProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (predictions) {
          if (predictions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_soccer, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum palpite realizado ainda',
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vá para Jogos e faça seus palpites!',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final filter = ref.watch(_predFilterProvider);
          final filtered = _applyFilter(predictions, filter);
          final groups = _groupSmart(filtered);

          return Column(
            children: [
              // Filter chips
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _FilterChip(label: 'Todos', value: 'all', provider: _predFilterProvider),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Agendados', value: 'scheduled', provider: _predFilterProvider),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Encerrados', value: 'finished', provider: _predFilterProvider),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(predictionsViewModelProvider.notifier).refresh(),
                  child: groups.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum palpite neste filtro',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final group = groups[index];
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
                                ...group.predictions.map(
                                  (p) => _PredictionCard(prediction: p),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<PredictionWithMatch> _applyFilter(
      List<PredictionWithMatch> predictions, String filter) {
    switch (filter) {
      case 'scheduled':
        return predictions
            .where((p) => p.match.status == 'SCHEDULED')
            .toList();
      case 'finished':
        return predictions
            .where((p) => p.match.status == 'FINISHED')
            .toList();
      default:
        return predictions;
    }
  }

  List<_PredictionGroup> _groupSmart(List<PredictionWithMatch> predictions) {
    final upcoming = predictions
        .where((p) => p.match.status != 'FINISHED')
        .toList()
      ..sort((a, b) => a.match.kickoffTime.compareTo(b.match.kickoffTime));

    final finished = predictions
        .where((p) => p.match.status == 'FINISHED')
        .toList()
      ..sort((a, b) => b.match.kickoffTime.compareTo(a.match.kickoffTime));

    final groups = <_PredictionGroup>[];
    if (upcoming.isNotEmpty) {
      groups.add(_PredictionGroup(label: '📅 Próximos', predictions: upcoming));
    }
    if (finished.isNotEmpty) {
      groups.add(_PredictionGroup(label: '✅ Encerrados', predictions: finished));
    }
    return groups;
  }
}

class _PredictionGroup {
  final String label;
  final List<PredictionWithMatch> predictions;
  _PredictionGroup({required this.label, required this.predictions});
}

class _FilterChip extends ConsumerWidget {
  final String label;
  final String value;
  final StateProvider<String> provider;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(provider);
    final isActive = current == value;
    return GestureDetector(
      onTap: () => ref.read(provider.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _TeamDisplay extends StatelessWidget {
  final String name;
  final String? crestUrl;

  const _TeamDisplay({required this.name, this.crestUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeamCrest(url: crestUrl, size: 26),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PredictionCard extends ConsumerStatefulWidget {
  final PredictionWithMatch prediction;
  const _PredictionCard({required this.prediction});

  @override
  ConsumerState<_PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends ConsumerState<_PredictionCard> {
  PredictionWithMatch get prediction => widget.prediction;

  void _navigateToPredictions(BuildContext context) {
    final m = prediction.match;
    final home = Uri.encodeComponent(m.homeTeamShort ?? m.homeTeamName);
    final away = Uri.encodeComponent(m.awayTeamShort ?? m.awayTeamName);
    final hs = m.scoreHome != null ? '&hs=${m.scoreHome}' : '';
    final as_ = m.scoreAway != null ? '&as=${m.scoreAway}' : '';
    context.push(
      '/matches/${m.externalId}/predictions?home=$home&away=$away&status=${m.status}$hs$as_',
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = prediction.match;
    final pts = prediction.points;
    final now = DateTime.now();
    final isEditable = m.status == 'SCHEDULED' &&
        m.kickoffTime.isAfter(now) &&
        m.kickoffTime.difference(now).inDays <= 1;
    final isLiveOrFinished = m.status != 'SCHEDULED';

    Color? ptsColor;
    if (pts != null) {
      if (pts >= 10) ptsColor = AppColors.success;
      else if (pts >= 5) ptsColor = Colors.orange;
      else ptsColor = AppColors.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLiveOrFinished
            ? () => _navigateToPredictions(context)
            : (isEditable ? () => _showEditDialog(context, ref, prediction) : null),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date + status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM HH:mm').format(m.kickoffTime.toLocal()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      _buildStatusBadge(m.status),
                      if (isLiveOrFinished) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Teams row
              Row(
                children: [
                  Expanded(
                    child: _TeamDisplay(
                      name: m.homeTeamShort ?? m.homeTeamName,
                      crestUrl: m.homeTeamCrest,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: m.status == 'FINISHED'
                        ? Text(
                            '${m.scoreHome ?? 0} - ${m.scoreAway ?? 0}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Text(
                            'vs',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                  Expanded(
                    child: _TeamDisplay(
                      name: m.awayTeamShort ?? m.awayTeamName,
                      crestUrl: m.awayTeamCrest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // Prediction row (destaque)
              Row(
                children: [
                  const Icon(Icons.sports_soccer, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  const Text(
                    'Meu palpite:',
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
                      '${prediction.predictedHome} × ${prediction.predictedAway}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isEditable)
                    TextButton.icon(
                      onPressed: () => _showEditDialog(context, ref, prediction),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Editar', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else if (pts != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    )
                  else if (m.status == 'FINISHED')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'Apurando...',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                      ),
                    )
                  else
                    const Text(
                      'Aguardando',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'LIVE':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'AO VIVO';
      case 'FINISHED':
        bg = Colors.grey.shade200;
        fg = AppColors.textSecondary;
        label = 'Encerrado';
      default:
        bg = Colors.blue.shade50;
        fg = AppColors.primary;
        label = 'Agendado';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

