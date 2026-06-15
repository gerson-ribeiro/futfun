class PredictionEntry {
  final String id;
  final String matchId; // DB UUID — used for PUT updates
  final int matchExternalId; // provider ID — used to link back to upcoming-matches data
  final int predictedHome;
  final int predictedAway;
  final int? points;
  final DateTime? scoredAt;

  const PredictionEntry({
    required this.id,
    required this.matchId,
    required this.matchExternalId,
    required this.predictedHome,
    required this.predictedAway,
    this.points,
    this.scoredAt,
  });

  factory PredictionEntry.fromJson(Map<String, dynamic> json) {
    return PredictionEntry(
      id: json['id'] as String,
      matchId: json['matchId'] as String,
      matchExternalId: json['matchExternalId'] as int? ?? 0,
      predictedHome: json['predictedHome'] as int,
      predictedAway: json['predictedAway'] as int,
      points: json['points'] as int?,
      scoredAt: json['scoredAt'] != null
          ? DateTime.parse(json['scoredAt'] as String)
          : null,
    );
  }
}
