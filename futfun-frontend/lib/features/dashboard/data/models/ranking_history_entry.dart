class RankingHistoryEntry {
  final String snapshotKey;
  final String roundStage;
  final int pointsEarned;
  final int totalPoints;
  final int position;
  final DateTime snapshotAt;

  const RankingHistoryEntry({
    required this.snapshotKey,
    required this.roundStage,
    required this.pointsEarned,
    required this.totalPoints,
    required this.position,
    required this.snapshotAt,
  });

  factory RankingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RankingHistoryEntry(
      snapshotKey: json['snapshotKey'] as String,
      roundStage: json['roundStage'] as String,
      pointsEarned: json['pointsEarned'] as int,
      totalPoints: json['totalPoints'] as int,
      position: json['position'] as int,
      snapshotAt: DateTime.parse(json['snapshotAt'] as String),
    );
  }
}
