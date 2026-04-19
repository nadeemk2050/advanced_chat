// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Global counter ensures every call gets a unique platform-view registration.
/// Using URL-hash alone causes silent collisions if two URLs share the same
/// Dart hashCode value.
int _webImgViewCounter = 0;

/// Registry of already-registered viewIds so we don't re-register on
/// hot-reload / repeated builds of the same URL.
final _registered = <String>{};

/// Renders a cross-origin Firebase Storage image using a real HTML <img>
/// element embedded via PlatformView.  A browser <img> src fetch is NOT
/// subject to XHR CORS — only XMLHttpRequest / fetch() are — so this
/// bypasses the "No Access-Control-Allow-Origin" block entirely.
Widget buildWebHtmlImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  // Stable ID for this URL so the same image isn't registered twice.
  final stableId = 'cors-img-${url.hashCode.abs()}-${url.length}';
  if (!_registered.contains(stableId)) {
    _registered.add(stableId);
    ui_web.platformViewRegistry.registerViewFactory(stableId, (int id) {
      return html.ImageElement()
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = _fitToCss(fit)
        ..style.borderRadius = '12px'
        ..style.display = 'block';
    });
  }
  return SizedBox(
    width: width,
    height: height ?? 150,
    child: HtmlElementView(viewType: stableId),
  );
}

String _fitToCss(BoxFit fit) {
  switch (fit) {
    case BoxFit.cover:
      return 'cover';
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    default:
      return 'cover';
  }
}
