class UserPredictionItem {
  final String matchHomeTeam;
  final String matchAwayTeam;
  final int? matchScoreHome;
  final int? matchScoreAway;
  final DateTime kickoffTime;
  final int predictedHome;
  final int predictedAway;
  final int? points;

  const UserPredictionItem({
    required this.matchHomeTeam,
    required this.matchAwayTeam,
    this.matchScoreHome,
    this.matchScoreAway,
    required this.kickoffTime,
    required this.predictedHome,
    required this.predictedAway,
    this.points,
  });

  factory UserPredictionItem.fromJson(Map<String, dynamic> json) {
    return UserPredictionItem(
      matchHomeTeam: json['matchHomeTeam'] as String,
      matchAwayTeam: json['matchAwayTeam'] as String,
      matchScoreHome: json['matchScoreHome'] as int?,
      matchScoreAway: json['matchScoreAway'] as int?,
      kickoffTime: DateTime.parse(json['kickoffTime'] as String),
      predictedHome: json['predictedHome'] as int,
      predictedAway: json['predictedAway'] as int,
      points: json['points'] as int?,
    );
  }
}
