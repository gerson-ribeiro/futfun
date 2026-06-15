import 'package:flutter/material.dart';

class AppColors {
  // Brand colors — same in both themes
  static const primary = Color(0xFF16a34a);
  static const secondary = Color(0xFFF57C00);
  static const success = Color(0xFF388E3C);
  static const error = Color(0xFFC62828);

  // Semantic helpers — prefer Theme.of(context).colorScheme where possible
  static const textSecondary = Color(0xFF757575);
}
