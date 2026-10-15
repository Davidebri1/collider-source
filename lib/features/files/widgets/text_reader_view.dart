// In-app text reader. Markdown is rendered as markdown (headings, lists, bold,
// italic, inline code, quotes, fences); code / csv / json get line numbers;
// everything else is set as prose.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/files/file_store.dart';
import '../../../core/files/text_probe.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/cpane.dart';

class TextReaderView extends StatefulWidget {
  final StoredFile file;
  final Uint8List bytes;

  const TextReaderView({super.key, required this.file, required this.bytes});

  @override
  State<TextReaderView> createState() => _TextReaderViewState();
}

class _TextReaderViewState extends State<TextReaderView> {
  static const int _maxChars = 200000;
  bool _showNumbers = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    var text = decodeText(widget.bytes);
    final cut = text.length > _maxChars;
    if (cut) text = text.substring(0, _maxChars);
    final lines = splitLines(text);
    final numbered = FileStore.isCode(f.name) || FileStore.isText(f.name) && !FileStore.isMarkdown(f.name);
    final markdown = FileStore.isMarkdown(f.name);

    final close = VCircleButton(
      icon: Icons.close_rounded,
      tooltip: 'Close',
      floating: true,
      onTap: () => Navigator.of(context).pop(),
    );
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.zero, // batch 4: CPane centres on the screen
          child: CPaneWindow(fit: CPaneFit.fill,
            title: f.name,
            leading: close,
            actions: [
              VCircleButton(
                icon: Icons.format_list_numbered_rounded,
                tooltip: _showNumbers ? 'Hide line numbers' : 'Show line numbers',
                selected: _showNumbers,
                onTap: () => setState(() => _showNumbers = !_showNumbers),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: EdgeFade(
                    child: markdown
                        ? _Markdown(lines: lines)
                        : _Lines(
                            lines: lines,
                            numbered: _showNumbers && numbered,
                            code: numbered,
                          ),
                  ),
                ),
                if (cut)
                  Padding(
                    padding: const EdgeInsets.only(top: VSpace.xs),
                    child: Text(
                      'Showing the first $_maxChars characters',
                      style: VType.caption(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Code and tabular text: monospace, with optional line numbers.
class _Lines extends StatelessWidget {
  final List<String> lines;
  final bool numbered;
  final bool code;

  const _Lines({required this.lines, required this.numbered, required this.code});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(VSpace.xl),
        child: Text('This file is empty.', style: TextStyle(color: VColors.textTertiary)),
      );
    }
    final gutter = numbered ? '${lines.length}'.length : 0;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.xs, VSpace.md, VSpace.md),
      child: SelectableText.rich(
        TextSpan(
          children: [
            for (var i = 0; i < lines.length; i++)
              TextSpan(children: [
                if (numbered)
                  TextSpan(
                    text: '${(i + 1).toString().padLeft(gutter)}  ',
                    style: VType.callout(weight: FontWeight.w400)
                        .copyWith(fontFamily: 'monospace', fontSize: 12, color: VColors.textTertiary),
                  ),
                TextSpan(
                  text: lines[i],
                  style: code
                      ? VType.callout(weight: FontWeight.w400).copyWith(fontFamily: 'monospace', fontSize: 12.5, height: 1.5)
                      : VType.body().copyWith(height: 1.6),
                ),
                const TextSpan(text: '\n'),
              ]),
          ],
        ),
      ),
    );
  }
}

/// A small markdown renderer: headings, lists, quotes, fences, bold, italic and
/// inline code. Enough to read a README properly; not a spec-compliant parser.
class _Markdown extends StatelessWidget {
  final List<String> lines;

  const _Markdown({required this.lines});

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    var i = 0;
    while (i < lines.length) {
      final raw = lines[i];
      final line = raw.trim();

      // Fenced code: swallow until the closing fence.
      if (line.startsWith('```')) {
        final lang = line.substring(3).trim();
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        i++; // closing fence
        blocks.add(_CodeBlock(lang: lang, code: buf.join('\n')));
        blocks.add(const SizedBox(height: VSpace.sm));
        continue;
      }

      if (line.isEmpty) {
        i++;
        continue;
      }

      // Headings.
      final hashes = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (hashes != null) {
        final level = hashes.group(1)!.length;
        blocks.add(_Mdp(
          text: hashes.group(2)!,
          style: switch (level) {
            1 => VType.title(),
            2 => VType.title2(),
            _ => VType.headline(),
          },
        ));
        i++;
        continue;
      }

      // Blockquote.
      if (line.startsWith('>')) {
        final buf = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          buf.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(_Mdp(
          text: buf.join('\n'),
          style: VType.footnote().copyWith(fontStyle: FontStyle.italic, color: VColors.textSecondary),
          left: true,
        ));
        continue;
      }

      // Bullet / numbered list.
      final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(line);
      if (bullet != null || numbered != null) {
        final items = <String>[];
        final ordered = numbered != null;
        while (i < lines.length) {
          final l = lines[i].trim();
          final b = RegExp(r'^[-*+]\s+(.*)$').firstMatch(l);
          final n = RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(l);
          if (b != null) {
            items.add(b.group(1)!);
          } else if (n != null) {
            items.add(n.group(1)!);
          } else if (l.isEmpty) {
            break;
          } else {
            // A continuation line: fold it into the previous item.
            if (items.isNotEmpty) items[items.length - 1] += ' $l';
          }
          i++;
        }
        blocks.add(_List(items: items, ordered: ordered));
        blocks.add(const SizedBox(height: VSpace.xs));
        continue;
      }

      // Horizontal rule.
      if (RegExp(r'^([-*_])\1{2,}$').hasMatch(line)) {
        blocks.add(const Divider(height: VSpace.xl, color: VColors.borderLight));
        i++;
        continue;
      }

      // Paragraph: join until a blank line or a new block marker.
      final buf = <String>[];
      while (i < lines.length) {
        final l = lines[i].trim();
        if (l.isEmpty ||
            l.startsWith('#') ||
            l.startsWith('```') ||
            l.startsWith('>') ||
            RegExp(r'^[-*+]\s').hasMatch(l) ||
            RegExp(r'^\d+[.)]\s').hasMatch(l)) {
          break;
        }
        buf.add(l);
        i++;
      }
      blocks.add(_Mdp(text: buf.join(' '), style: VType.body().copyWith(height: 1.55)));
      blocks.add(const SizedBox(height: VSpace.xs));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.xs, VSpace.md, VSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks),
    );
  }
}

class _Mdp extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool left;

  const _Mdp({required this.text, required this.style, this.left = false});

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: EdgeInsets.only(left: left ? VSpace.sm : 0, top: 2, bottom: 2),
      child: RichText(text: _inline(text, style)),
    );
    return left
        ? Container(
            padding: const EdgeInsets.only(left: VSpace.sm),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: VColors.borderHeavy, width: 2)),
            ),
            child: body,
          )
        : body;
  }
}

/// Bold, italic and inline code inside one line.
TextSpan _inline(String text, TextStyle base) {
  final spans = <TextSpan>[];
  final re = RegExp(r'(\*\*[^*]+\*\*|_[^_]+_|\*[^*]+\*|`[^`]+`)');
  var at = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
    final t = m.group(0)!;
    if (t.startsWith('**')) {
      spans.add(TextSpan(text: t.substring(2, t.length - 2), style: base.copyWith(fontWeight: FontWeight.w700)));
    } else if (t.startsWith('`')) {
      spans.add(TextSpan(
        text: t.substring(1, t.length - 1),
        style: base.copyWith(fontFamily: 'monospace', color: VColors.accentTeal),
      ));
    } else {
      spans.add(TextSpan(text: t.substring(1, t.length - 1), style: base.copyWith(fontStyle: FontStyle.italic)));
    }
    at = m.end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return TextSpan(style: base, children: spans);
}

class _List extends StatelessWidget {
  final List<String> items;
  final bool ordered;

  const _List({required this.items, required this.ordered});

  @override
  Widget build(BuildContext context) {
    final style = VType.body().copyWith(height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3, left: VSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(ordered ? '${i + 1}.' : '•', style: style.copyWith(color: VColors.textSecondary)),
                ),
                Expanded(child: RichText(text: _inline(items[i], style))),
              ],
            ),
          ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String lang;
  final String code;

  const _CodeBlock({required this.lang, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSpace.sm),
      decoration: BoxDecoration(
        color: VColors.fillRecessed,
        borderRadius: BorderRadius.circular(VRadius.sm),
        border: Border.all(color: VColors.borderLight, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lang.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(lang, style: VType.caption().copyWith(color: VColors.textTertiary)),
            ),
          SelectableText(
            code,
            style: VType.callout(weight: FontWeight.w400).copyWith(fontFamily: 'monospace', fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}