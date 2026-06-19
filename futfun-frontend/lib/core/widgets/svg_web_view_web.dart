// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert' show base64Encode;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

final _registered = <String>{};

Widget buildSvgWebView(String url, Uint8List bytes, double size) {
  // Key includes size so different render sizes get their own factory.
  final viewType = 'futfun-svg-${url.hashCode.abs()}-${size.toInt()}';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    final dataUrl = 'data:image/svg+xml;base64,${base64Encode(bytes)}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
      return html.ImageElement()
        ..src = dataUrl
        ..style.width = '${size}px'
        ..style.height = '${size}px'
        ..style.objectFit = 'contain';
    });
  }
  return SizedBox(
    width: size,
    height: size,
    child: HtmlElementView(viewType: viewType),
  );
}
