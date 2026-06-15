import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';

/// Displays a team's crest image from a URL.
///
/// On web, images are routed through the backend proxy (/api/image-proxy)
/// because external CDNs (crests.football-data.org, thesportsdb.com) do not
/// send CORS headers, blocking direct browser requests.
///
/// On mobile, images are fetched directly (no CORS restriction).
///
/// Falls back to a soccer-ball icon when the URL is null or fails to load.
class TeamCrest extends StatelessWidget {
  final String? url;
  final double size;

  static const _backendUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://futfun-backend-dlpljkbcta-rj.a.run.app',
  );

  const TeamCrest({super.key, this.url, this.size = 28});

  /// On web, wraps the URL through the backend CORS proxy.
  String _effectiveUrl(String original) {
    if (!kIsWeb) return original;
    return '$_backendUrl/api/image-proxy?url=${Uri.encodeComponent(original)}';
  }

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _placeholder();

    final effective = _effectiveUrl(url!);

    // SVG files: use flutter_svg on all platforms
    if (url!.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        effective,
        width: size,
        height: size,
        placeholderBuilder: (_) => _placeholder(),
      );
    }

    // Raster images (PNG, JPG, etc.)
    return Image.network(
      effective,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        Icons.sports_soccer,
        size: size * 0.78,
        color: AppColors.textSecondary,
      ),
    );
  }
}
