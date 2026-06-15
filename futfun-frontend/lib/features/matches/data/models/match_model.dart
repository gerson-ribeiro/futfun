class MatchModel {
  final String id; // externalId.toString() for upcoming-matches; DB UUID for predictions screen
  final int externalId;
  final String competitionCode;
  final String competitionName;
  final int homeTeamId;
  final String homeTeamName;
  final String? homeTeamShort;
  final String? homeTeamCrest;
  final String? homeTeamType;
  final int awayTeamId;
  final String awayTeamName;
  final String? awayTeamShort;
  final String? awayTeamCrest;
  final String? awayTeamType;
  final DateTime kickoffTime;
  final String status; // SCHEDULED, LIVE, FINISHED
  final int? scoreHome;
  final int? scoreAway;
  final String stage;
  final String? groupName;
  final int? matchday;
  final bool hasPrediction;

  const MatchModel({
    required this.id,
    required this.externalId,
    required this.competitionCode,
    required this.competitionName,
    required this.homeTeamId,
    required this.homeTeamName,
    this.homeTeamShort,
    this.homeTeamCrest,
    this.homeTeamType,
    required this.awayTeamId,
    required this.awayTeamName,
    this.awayTeamShort,
    this.awayTeamCrest,
    this.awayTeamType,
    required this.kickoffTime,
    required this.status,
    this.scoreHome,
    this.scoreAway,
    required this.stage,
    this.groupName,
    this.matchday,
    this.hasPrediction = false,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final extId = json['externalId'] as int? ?? 0;
    return MatchModel(
      id: json['id'] as String,
      externalId: extId,
      competitionCode: json['competitionCode'] as String? ?? '',
      competitionName: json['competitionName'] as String? ?? '',
      homeTeamId: json['homeTeamId'] as int? ?? 0,
      homeTeamName: json['homeTeamName'] as String,
      homeTeamShort: json['homeTeamShort'] as String?,
      homeTeamCrest: json['homeTeamCrest'] as String?,
      homeTeamType: json['homeTeamType'] as String?,
      awayTeamId: json['awayTeamId'] as int? ?? 0,
      awayTeamName: json['awayTeamName'] as String,
      awayTeamShort: json['awayTeamShort'] as String?,
      awayTeamCrest: json['awayTeamCrest'] as String?,
      awayTeamType: json['awayTeamType'] as String?,
      kickoffTime: DateTime.parse(json['kickoffTime'] as String),
      status: json['status'] as String,
      scoreHome: json['scoreHome'] as int?,
      scoreAway: json['scoreAway'] as int?,
      stage: json['stage'] as String,
      groupName: json['groupName'] as String?,
      matchday: json['matchday'] as int?,
      hasPrediction: json['hasPrediction'] as bool? ?? false,
    );
  }
}
