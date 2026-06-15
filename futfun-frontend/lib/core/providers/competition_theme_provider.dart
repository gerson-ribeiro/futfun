// lib/core/providers/competition_theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'active_competition_provider.dart';

Color _parseHex(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF16a34a);
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return const Color(0xFF16a34a);
  }
}

final competitionPrimaryColorProvider = Provider<Color>((ref) {
  final state = ref.watch(activeCompetitionNotifierProvider).valueOrNull;
  return _parseHex(state?.selected?.color);
});
