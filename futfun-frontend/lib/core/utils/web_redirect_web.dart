// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Redirects the current browser tab to [url], replacing the current history entry.
void redirectCurrentPage(String url) {
  html.window.location.href = url;
}
