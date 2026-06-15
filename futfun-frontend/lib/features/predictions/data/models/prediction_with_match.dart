import '../../../matches/data/models/match_model.dart';

class PredictionWithMatch {
  final String id;
  final String matchId;
  final int predictedHome;
  final int predictedAway;
  final int? points;
  final DateTime? scoredAt;
  final MatchModel match;

  const PredictionWithMatch({
    required this.id,
    required this.matchId,
    required this.predictedHome,
    required this.predictedAway,
    this.points,
    this.scoredAt,
    required this.match,
  });

  factory PredictionWithMatch.fromJson(Map<String, dynamic> json) {
    return PredictionWithMatch(
      id: json['id'] as String,
      matchId: json['matchId'] as String,
      predictedHome: json['predictedHome'] as int,
      predictedAway: json['predictedAway'] as int,
      points: json['points'] as int?,
      scoredAt: json['scoredAt'] != null
          ? DateTime.parse(json['scoredAt'] as String)
          : null,
      match: MatchModel.fromJson(json['match'] as Map<String, dynamic>),
    );
  }
}
