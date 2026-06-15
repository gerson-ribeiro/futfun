import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/ranking_history_entry.dart';

class PointsLineChart extends StatelessWidget {
  final List<RankingHistoryEntry> history;

  const PointsLineChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Sem dados históricos ainda',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalPoints.toDouble());
    }).toList();

    final maxY = history.map((e) => e.totalPoints).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: (maxY * 1.15).ceilToDouble(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: history.length <= 6 ? 1 : (history.length / 6).ceilToDouble(),
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= history.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        history[idx].roundStage.length > 6
                            ? history[idx].roundStage.substring(0, 6)
                            : history[idx].roundStage,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: AppColors.success.withOpacity(0.9),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final idx = spot.x.toInt();
                    final entry = history[idx];
                    return LineTooltipItem(
                      '${entry.roundStage}\n${entry.totalPoints} pts (+${entry.pointsEarned})',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.success,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.success,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.success.withOpacity(0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
