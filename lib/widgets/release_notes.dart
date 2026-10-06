import 'package:flutter/material.dart';

/// One parsed line of a GitHub release body.
class NotesBlock {
  const NotesBlock.heading(this.text, {this.level = 3}) : isBullet = false;
  const NotesBlock.bullet(this.text) : isBullet = true, level = 0;
  const NotesBlock.paragraph(this.text) : isBullet = false, level = 0;

  final String text;
  final bool isBullet;
  final int level;
}

/// Splits a release body into renderable blocks.
///
/// Handles the subset of Markdown that Mirai's changelogs use: ATX headings,
/// `-`/`*` bullets, `###` sub-sections, and blank-line paragraphs. Anything
/// else falls through as paragraph text so a new release body never renders
/// blank.
class ReleaseNotesParser {
  static List<NotesBlock> parse(String body) {
    final blocks = <NotesBlock>[];
    final paragraph = <String>[];

    void flush() {
      if (paragraph.isEmpty) return;
      final text = paragraph.join(' ').trim();
      if (text.isNotEmpty) blocks.add(NotesBlock.paragraph(text));
      paragraph.clear();
    }

    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) {
        flush();
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flush();
        blocks.add(NotesBlock.heading(
          heading.group(2)!.trim(),
          level: heading.group(1)!.length,
        ));
        continue;
      }

      final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flush();
        blocks.add(NotesBlock.bullet(_stripCheckbox(bullet.group(1)!)));
        continue;
      }

      final check = RegExp(r'^\[( |x|X)\]\s+(.*)$').firstMatch(trimmed);
      if (check != null) {
        flush();
        blocks.add(NotesBlock.bullet(check.group(2)!.trim()));
        continue;
      }

      paragraph.add(trimmed.trim());
    }

    flush();
    return blocks;
  }
}

/// Renders a parsed changelog with the app's own text theme.
class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView({super.key, required this.body, this.textStyle});

  final String body;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final blocks = ReleaseNotesParser.parse(body);
    if (blocks.isEmpty) return const SizedBox.shrink();
    final base = textStyle ?? Theme.of(context).textTheme.bodyMedium!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          if (block.isBullet)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: base.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: _inline(block.text, base)),
                ],
              ),
            )
          else if (block.level > 0)
            Padding(
              padding: EdgeInsets.only(
                top: block.level <= 2 ? 18 : 12,
                bottom: 6,
              ),
              child: Text(
                _stripInline(block.text),
                style: base.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: base.fontSize != null
                      ? base.fontSize! * (block.level <= 2 ? 1.06 : 1.0)
                      : null,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _inline(block.text, base),
            ),
        ],
      ],
    );
  }

  /// Minimal inline emphasis: `code` and **bold** become styled spans.
  Widget _inline(String text, TextStyle base) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'`([^`]+)`|\*\*([^*]+)\*\*');
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final code = match.group(1);
      final bold = match.group(2);
      if (code != null) {
        spans.add(TextSpan(
          text: code,
          style: base.copyWith(
            fontFamily: 'monospace',
            fontSize: (base.fontSize ?? 14) - 1,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: base, children: spans));
  }

  /// `- [x] Fixed` is a bullet whose label is just `Fixed`.
  static String _stripCheckbox(String text) =>
      text.replaceFirst(RegExp(r'^\[( |x|X)\]\s+'), '').trim();

  static String _stripInline(String text) =>
      text.replaceAllMapped(RegExp(r'`([^`]+)`|\*\*([^*]+)\*\*'), (m) {
        return m.group(1) ?? m.group(2) ?? '';
      });
}