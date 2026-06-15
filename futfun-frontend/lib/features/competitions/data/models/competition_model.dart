// lib/features/competitions/data/models/competition_model.dart

class CompetitionModel {
  final String code;
  final String name;
  final bool enabled;
  final bool hidden;
  final String? color;
  final bool hasRankingData;

  const CompetitionModel({
    required this.code,
    required this.name,
    required this.enabled,
    this.hidden = false,
    this.color,
    this.hasRankingData = false,
  });

  factory CompetitionModel.fromJson(Map<String, dynamic> json) {
    return CompetitionModel(
      code: json['code'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool,
      hidden: json['hidden'] as bool? ?? false,
      color: json['color'] as String?,
      hasRankingData: json['hasRankingData'] as bool? ?? false,
    );
  }

  CompetitionModel copyWith({bool? hidden, bool? enabled}) {
    return CompetitionModel(
      code: code,
      name: name,
      enabled: enabled ?? this.enabled,
      hidden: hidden ?? this.hidden,
      color: color,
      hasRankingData: hasRankingData,
    );
  }
}
