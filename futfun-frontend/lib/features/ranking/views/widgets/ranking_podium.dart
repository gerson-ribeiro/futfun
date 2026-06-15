import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/ranking_entry.dart';

class RankingPodium extends StatelessWidget {
  final List<RankingEntry> top3;

  const RankingPodium({super.key, required this.top3});

  @override
  Widget build(BuildContext context) {
    if (top3.isEmpty) return const SizedBox.shrink();

    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(0.08),
            AppColors.success.withOpacity(0.04),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place (left)
          Expanded(child: _PodiumSlot(entry: second, rank: 2, height: 80)),
          // 1st place (center, taller)
          Expanded(child: _PodiumSlot(entry: first, rank: 1, height: 110)),
          // 3rd place (right)
          Expanded(child: _PodiumSlot(entry: third, rank: 3, height: 60)),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final RankingEntry? entry;
  final int rank;
  final double height;

  const _PodiumSlot({
    required this.entry,
    required this.rank,
    required this.height,
  });

  static const _medals = ['', '🥇', '🥈', '🥉'];
  static const _colors = [
    Colors.transparent,
    Color(0xFFFFD700), // gold
    Color(0xFFB0BEC5), // silver
    Color(0xFFBF8C60), // bronze
  ];

  @override
  Widget build(BuildContext context) {
    if (entry == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Medal circle
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _colors[rank].withOpacity(0.25),
            shape: BoxShape.circle,
            border: Border.all(color: _colors[rank], width: 2),
          ),
          child: Center(
            child: Text(
              _medals[rank],
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          entry!.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry!.totalPoints} pts',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.success,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        // Podium block
        Container(
          height: height,
          decoration: BoxDecoration(
            color: _colors[rank].withOpacity(0.18),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            border: Border(
              top: BorderSide(color: _colors[rank], width: 2),
              left: BorderSide(color: _colors[rank].withOpacity(0.4), width: 1),
              right: BorderSide(color: _colors[rank].withOpacity(0.4), width: 1),
            ),
          ),
          child: Center(
            child: Text(
              '$rank°',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _colors[rank],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
