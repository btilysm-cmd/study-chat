import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Shared typography and spacing for assistant markdown in chat and branches.
class StudyMarkdownTheme extends StatefulWidget {
  const StudyMarkdownTheme({super.key, required this.child});

  final Widget child;

  @override
  State<StudyMarkdownTheme> createState() => _StudyMarkdownThemeState();
}

class _StudyMarkdownThemeState extends State<StudyMarkdownTheme> {
  ThemeData? _theme;
  GptMarkdownThemeData? _data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!identical(theme, _theme) || _data == null) {
      _theme = theme;
      _data = _buildTheme(theme);
    }
    return GptMarkdownTheme(gptThemeData: _data!, child: widget.child);
  }

  GptMarkdownThemeData _buildTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final base = TextStyle(
      color: scheme.onSurface,
      fontSize: 15.5,
      height: 1.65,
    );
    return GptMarkdownThemeData(
      brightness: theme.brightness,
      h1: base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.35,
      ),
      h2: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.35,
      ),
      h3: base.copyWith(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      h4: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
      h5: base.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      h6: base.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      autoAddDividerLineAfterH1: false,
      linkColor: scheme.primary,
      linkHoverColor: scheme.primary,
      styleSheet: const GptMarkdownStyleSheet(
        latex: LatexStyle(
          textStyle: TextStyle(fontSize: 14.5),
          scrollBlockHorizontally: true,
        ),
        codeBlock: CodeBlockStyle(fontSize: 13, highlightWhileStreaming: false),
        heading: HeadingStyle(padding: EdgeInsets.only(top: 6, bottom: 2)),
        blockSpacing: 10,
      ),
    );
  }
}

GptMarkdownConfig studyMarkdownConfig(
  BuildContext context, {
  required ValueChanged<String> onLinkTap,
  required ValueChanged<String> onCodeCopy,
  ValueChanged<String>? onImageTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  return GptMarkdownConfig(
    style: TextStyle(fontSize: 15.5, height: 1.65, color: scheme.onSurface),
    onLinkTap: (url, title) => onLinkTap(url),
    onCodeCopy: onCodeCopy,
    onImageTap: onImageTap,
    styleSheet: const GptMarkdownStyleSheet(
      latex: LatexStyle(scrollBlockHorizontally: true),
    ),
  );
}
