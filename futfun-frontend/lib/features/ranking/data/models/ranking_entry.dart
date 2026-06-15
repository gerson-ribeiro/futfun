class RankingEntry {
  final int position;
  final String userId;
  final String displayName;
  final int totalPoints;
  final int exactScores;
  final int correctResults;
  final int matchesPredicted;

  const RankingEntry({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.totalPoints,
    required this.exactScores,
    required this.correctResults,
    required this.matchesPredicted,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      position: json['position'] as int,
      userId: json['userId'] as String,
      displayName: json['displayName'] as String? ?? '',
      totalPoints: json['totalPoints'] as int,
      exactScores: json['exactScores'] as int,
      correctResults: json['correctResults'] as int,
      matchesPredicted: json['matchesPredicted'] as int,
    );
  }
}
