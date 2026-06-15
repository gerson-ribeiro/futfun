import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/team_crest.dart';
import '../../data/models/match_model.dart';
import '../../viewmodels/matches_viewmodel.dart';
import 'prediction_input.dart';

class MatchCard extends ConsumerWidget {
  final MatchModel match;
  final String competitionCode;

  const MatchCard({
    super.key,
    required this.match,
    required this.competitionCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vmState = ref.watch(matchesViewModelProvider(competitionCode));
    final isSubmitting = vmState.valueOrNull?.submittingMatchId == match.id;

    // Janela de palpites: aberta no dia anterior ao jogo (por data de calendário,
    // não por horas). Usa horário local para evitar que jogos das 21:00 BRT
    // (= 00:00 UTC do dia seguinte) apareçam bloqueados na véspera.
    final now = DateTime.now();
    final kickoffLocal = match.kickoffTime.toLocal();

    // Comparação por data de calendário (sem horário)
    final todayDate = DateTime(now.year, now.month, now.day);
    final tomorrowDate = todayDate.add(const Duration(days: 1));
    final kickoffDate = DateTime(kickoffLocal.year, kickoffLocal.month, kickoffLocal.day);

    final canBet = kickoffLocal.isAfter(now) && !kickoffDate.isAfter(tomorrowDate);
    // Quantos dias até a janela abrir (= dia antes do jogo = kickoffDate - 1)
    final daysUntilWindowOpens = kickoffDate.difference(tomorrowDate).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: date/time + locked badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM HH:mm').format(kickoffLocal),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!canBet && kickoffLocal.isAfter(now))
                  _LockedBadge(daysUntilWindowOpens: daysUntilWindowOpens),
              ],
            ),
            const SizedBox(height: 10),
            // Teams row
            Row(
              children: [
                Expanded(
                  child: _TeamDisplay(
                    name: match.homeTeamShort ?? match.homeTeamName,
                    crestUrl: match.homeTeamCrest,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'vs',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: _TeamDisplay(
                    name: match.awayTeamShort ?? match.awayTeamName,
                    crestUrl: match.awayTeamCrest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Prediction area
            if (canBet)
              PredictionInput(
                matchId: match.id,
                kickoffTime: match.kickoffTime,
                isSubmitting: isSubmitting,
                onSubmit: (home, away) {
                  ref
                      .read(matchesViewModelProvider(competitionCode).notifier)
                      .submitPrediction(match.id, home, away);
                },
              ),
          ],
        ),
      ),
    );
  }
}


/// Badge âmbar exibido quando a janela de palpites ainda não abriu.
class _LockedBadge extends StatelessWidget {
  final int daysUntilWindowOpens;
  const _LockedBadge({required this.daysUntilWindowOpens});

  @override
  Widget build(BuildContext context) {
    final label = daysUntilWindowOpens <= 1
        ? 'Abre amanhã'
        : 'Abre em $daysUntilWindowOpens dias';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock, size: 12, color: Colors.amber.shade800),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.amber.shade800,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
        TeamCrest(url: crestUrl, size: 30),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
