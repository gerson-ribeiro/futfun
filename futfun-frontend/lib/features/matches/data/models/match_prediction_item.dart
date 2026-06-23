class MatchPredictionItem {
  final String displayName;
  final int predictedHome;
  final int predictedAway;
  final int? points;
  final bool isCurrentUser;

  const MatchPredictionItem({
    required this.displayName,
    required this.predictedHome,
    required this.predictedAway,
    this.points,
    this.isCurrentUser = false,
  });

  factory MatchPredictionItem.fromJson(Map<String, dynamic> json) {
    return MatchPredictionItem(
      displayName: json['displayName'] as String,
      predictedHome: json['predictedHome'] as int,
      predictedAway: json['predictedAway'] as int,
      points: json['points'] as int?,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }
}
