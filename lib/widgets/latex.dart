import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Removes TeX commands the bundled math renderer does not understand
/// (proof markers, equation labels/tags, numbering controls).
String sanitizeTex(String source) {
  var text = source;
  text = text.replaceAll(RegExp(r'\\(qedhere|qed)\b'), '□');
  text = text.replaceAll(RegExp(r'\\(nonumber|notag)\b'), '');
  text = text.replaceAll(RegExp(r'\\(label|tag|eqref|ref)\s*\{[^{}]*\}'), '');
  return text;
}

Widget mathWidget(String tex, {bool display = false, TextStyle? textStyle}) {
  final clean = sanitizeTex(tex);
  final style = textStyle ?? const TextStyle(fontSize: 15.5);
  return Math.tex(
    clean,
    mathStyle: display ? MathStyle.display : MathStyle.text,
    textStyle: style,
    onErrorFallback: (error) => Text(
      clean,
      style: style.copyWith(
        fontFamily: 'monospace',
        fontSize: (style.fontSize ?? 15.5) * 0.9,
      ),
    ),
  );
}
