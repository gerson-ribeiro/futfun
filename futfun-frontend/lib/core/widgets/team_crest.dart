import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import 'svg_web_view_stub.dart'
    if (dart.library.html) 'svg_web_view_web.dart';

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

  // Bare Dio for image fetching — no auth interceptors, no base URL.
  static final _imageDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Simple in-memory cache to avoid re-fetching the same image.
  static final _imageCache = <String, Uint8List>{};

  const TeamCrest({super.key, this.url, this.size = 28});

  /// On web, wraps the URL through the backend CORS proxy.
  String _effectiveUrl(String original) {
    if (!kIsWeb) return original;
    return '$_backendUrl/api/image-proxy?url=${Uri.encodeComponent(original)}';
  }

  bool _isSvg(String url) {
    // Strip query params before checking extension.
    final path = url.toLowerCase().split('?').first;
    return path.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _placeholder();

    final effective = _effectiveUrl(url!);

    // On web, flutter_svg fails on SVGs with percentage-based transforms
    // (e.g. translate(100%, -50%)). Fetch bytes via Dio and hand off to the
    // browser's native SVG engine via HtmlElementView.
    if (_isSvg(url!) && kIsWeb) {
      return _WebSvgImage(
        url: effective,
        size: size,
        placeholder: _placeholder(),
        dio: _imageDio,
        cache: _imageCache,
      );
    }

    // SVG files on native platforms: use flutter_svg.
    if (_isSvg(url!)) {
      return SvgPicture.network(
        effective,
        width: size,
        height: size,
        placeholderBuilder: (_) => _placeholder(),
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    // On web, Image.network() may use an opaque (no-cors) fetch mode for
    // cross-origin URLs, causing the image to load (HTTP 200) but never
    // render because the browser restricts byte access. Fetching via Dio
    // makes a standard CORS GET request that correctly receives the proxy's
    // Access-Control-Allow-Origin header and exposes the bytes.
    if (kIsWeb) {
      return _WebRasterImage(
        url: effective,
        size: size,
        placeholder: _placeholder(),
        dio: _imageDio,
        cache: _imageCache,
      );
    }

    // Raster images (PNG, JPG, etc.) on native platforms.
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

/// Fetches an SVG via Dio and renders it using the browser's native SVG engine
/// (HtmlElementView). Used only on Flutter Web because flutter_svg cannot
/// handle SVGs with percentage-based transform values.
class _WebSvgImage extends StatefulWidget {
  final String url;
  final double size;
  final Widget placeholder;
  final Dio dio;
  final Map<String, Uint8List> cache;

  const _WebSvgImage({
    required this.url,
    required this.size,
    required this.placeholder,
    required this.dio,
    required this.cache,
  });

  @override
  State<_WebSvgImage> createState() => _WebSvgImageState();
}

class _WebSvgImageState extends State<_WebSvgImage> {
  late final Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchBytes();
  }

  Future<Uint8List> _fetchBytes() async {
    final cached = widget.cache[widget.url];
    if (cached != null) return cached;
    final response = await widget.dio.get<List<int>>(
      widget.url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data!);
    widget.cache[widget.url] = bytes;
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return buildSvgWebView(widget.url, snapshot.data!, widget.size);
        }
        return widget.placeholder;
      },
    );
  }
}

/// Fetches a raster image via Dio (proper CORS GET) and renders with Image.memory.
/// Used only on Flutter Web to bypass Image.network()'s opaque-fetch limitation.
class _WebRasterImage extends StatefulWidget {
  final String url;
  final double size;
  final Widget placeholder;
  final Dio dio;
  final Map<String, Uint8List> cache;

  const _WebRasterImage({
    required this.url,
    required this.size,
    required this.placeholder,
    required this.dio,
    required this.cache,
  });

  @override
  State<_WebRasterImage> createState() => _WebRasterImageState();
}

class _WebRasterImageState extends State<_WebRasterImage> {
  late final Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchBytes();
  }

  Future<Uint8List> _fetchBytes() async {
    final cached = widget.cache[widget.url];
    if (cached != null) return cached;

    final response = await widget.dio.get<List<int>>(
      widget.url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data!);
    widget.cache[widget.url] = bytes;
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => widget.placeholder,
          );
        }
        if (snapshot.hasError) {
          return widget.placeholder;
        }
        return widget.placeholder;
      },
    );
  }
}
