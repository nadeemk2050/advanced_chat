import 'package:flutter/material.dart';

Widget buildWebHtmlImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  // Non-web stub — never called when kIsWeb is false.
  return Container(
    width: width,
    height: height ?? 150,
    color: Colors.white12,
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, color: Colors.white54),
  );
}
