// Map row 13 (Media Gen Ticker Layout) — wechat IMAGE 2013:71.
//
// This used to be a FigmaStage: the 2610x1468 landscape scene scaled as one
// unit, cropped to the tab bar and centred. At 430pt that scale is 0.2456, so
// the 76pt action bar came out as 18.7pt circles and the 348pt side panel as
// an 85pt sliver, and the whole thing was Positioned.fill under a composer and
// a ticker - three layers of UI in the same space. It is the same
// scaled-landscape bug the ticker and the rail had.
//
// Drawn natively instead. The reference's OWN boxes keep their reference
// ratios: the media window holds its 1285x754 aspect, the action bar stays
// centred under that window, the pager stays under the bar. What changes is
// that the controls are real size - Kit.controlCircle, the same as the dock -
// instead of 0.2456 of themselves.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/figma/figma_stage.dart';
import '../../core/kit/collider_kit.dart';
import '../../core/vision/vision_kit.dart';
import '../../core/files/file_store.dart';
import '../ticker/widgets/figma_ticker.dart' show ModelDisc;
import 'media_ticker.dart' show MediaGeneration;
import 'media_view.dart';

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Geometry for row 13, resolved against the field the host actually has.
///
/// The host hands down the rectangle above the composer, so the media window
/// and the list below it can never grow into the ticker - the collision was
/// structural, not a z-order accident.
class MediaStageLayout {
  const MediaStageLayout(this.field);

  final Rect field;

  /// Air around the group. Same clause as the ticker: visionOS floats.
  static const double gutter = 12;

  /// The reference media window is 1285 x 754.
  static const double aspect = 1285 / 754;

  /// Action pill + pager + the minimum the runs/prompts pane needs to read.
  static const double _rest = 190;

  double get mediaW => field.width;

  /// The reference aspect, then whatever is left after the rest of the group
  /// has taken its share - so on a short screen the list shrinks, not the media.
  double get mediaH => math.min(mediaW / aspect, math.max(120.0, field.height - _rest));

  double get barH => Kit.controlCircle + 12;

  Rect get media => Rect.fromLTWH(field.left, field.top, mediaW, mediaH);

  Rect get bar {
    const w = Kit.controlCircle * 4 + 6 * 3 + 12;
    return Rect.fromLTWH(field.center.dx - w / 2, media.bottom + 10, w, barH);
  }

  Rect get pager {
    const h = 12.0;
    return Rect.fromLTWH(field.left, bar.bottom + 8, field.width, h);
  }

  Rect get runs {
    final top = pager.bottom + 10;
    return Rect.fromLTWH(field.left, top, field.width, math.max(0.0, field.bottom - top));
  }

  static MediaStageLayout forField(Size viewport, {double floorTop = 0}) {
    // The rail is a persistent edge control at x 12..56. A field that runs the
    // full width would sit under it - which is exactly what happened: the rail
    // covered the "Models" heading and the first prompt card. The field is the
    // space beside the rail, so it starts where the rail ends.
    const left = gutter + Kit.controlCircle + gutter;
    return MediaStageLayout(
      Rect.fromLTRB(
        left,
        gutter,
        viewport.width - gutter,
        floorTop > 0 ? math.max(gutter, floorTop - gutter) : viewport.height - 120,
      ),
    );
  }
}

class MediaStageContent extends StatefulWidget {
  const MediaStageContent({super.key, required this.field, required this.items, required this.onRemix, required this.onNotice, required this.onOptions});
  final Rect field;
  final List<MediaGeneration> items;
  final ValueChanged<String> onRemix;
  final void Function(String) onNotice;
  final VoidCallback onOptions;
  @override
  State<MediaStageContent> createState() => _MediaStageContentState();
}

class _MediaStageContentState extends State<MediaStageContent> {
  int _i = 0;

  Future<void> _save(MediaGeneration g) async {
    final u = g.url;
    if (u == null || !u.startsWith('data:')) return;
    final comma = u.indexOf(',');
    final mime = u.substring(5, u.indexOf(';'));
    final ext = mime.split('/').last.replaceAll('jpeg', 'jpg');
    final name = '${g.model.label} ${g.at.millisecondsSinceEpoch}.$ext';
    final note = await FileStore.instance.addBytes(name, base64Decode(u.substring(comma + 1)), 'model');
    widget.onNotice(note ?? 'Saved to Files');
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final i = _i.clamp(0, items.length - 1);
    final g = items[i];
    final L = MediaStageLayout(widget.field);

    return Stack(children: [
      // Media window (Rectangle 22), holding its reference aspect.
      Positioned.fromRect(
        rect: L.media,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x4DFFFFFF), width: 1),
            ),
            child: g.pending || g.url == null
                ? const FGlass(child: Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))))
                : GenMediaView(key: ValueKey(g.url!.hashCode), url: g.url!, kind: g.kind),
          ),
        ),
      ),

      // Action bar 36:1867 - Remix / Options / Save to Files / Copy prompt.
      // Centred under the media window, at real control size.
      Positioned.fromRect(
        rect: L.bar,
        child: FGlass(
          radius: BorderRadius.circular(999),
          stroke: const Color(0x66FFFFFF),
          strokeWidth: 1,
          shadow: Kit.shadow(3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              VCircleButton(icon: Icons.reply_rounded, tooltip: 'Remix', size: Kit.controlCircle, onTap: () => widget.onRemix(g.prompt)),
              VCircleButton(icon: Icons.tune_rounded, tooltip: 'Options', size: Kit.controlCircle, onTap: widget.onOptions),
              VCircleButton(icon: Icons.download_rounded, tooltip: 'Save to Files', size: Kit.controlCircle, onTap: g.url == null ? null : () => _save(g)),
              VCircleButton(
                icon: Icons.content_copy_rounded,
                tooltip: 'Copy prompt',
                size: Kit.controlCircle,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: g.prompt));
                  widget.onNotice('Copied');
                },
              ),
            ],
          ),
        ),
      ),

      // Window controls 35:1826 -> the pager.
      Positioned.fromRect(
        rect: L.pager,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var k = 0; k < items.length; k++) ...[
              if (k > 0) const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _i = k),
                child: Container(
                  width: k == i ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(k == i ? 0.85 : 0.35), borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ],
        ),
      ),

      // Side panel 59:498 -> in portrait it is a window under the media, not a
      // column beside it: "likes" (the models that ran) then "comments" (each
      // generation). Same content, same order, on the axis that has room.
      Positioned.fromRect(
        rect: L.runs,
        child: FGlass(
          radius: BorderRadius.circular(28),
          stroke: const Color(0x4DFFFFFF),
          shadow: Kit.shadow(3),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const FText('Models', size: 17, height: 22, weight: FontWeight.w700),
              const SizedBox(width: 8),
              FText('${items.length}', size: 15, height: 22, weight: FontWeight.w700, opacity: 0.4),
            ]),
            const SizedBox(height: 10),
            // 37px discs 32 apart - the reference's own avatar cluster
            // (31.6 pitch on a 37 disc), which overlaps rather than spaces.
            // Absolutely positioned: a negative margin asserts in Container,
            // and the overlap is the point, so it is a pitch, not an inset.
            ClipRect(
              child: SizedBox(
                height: 40,
                width: math.min(L.runs.width - 32, 32.0 * (items.length - 1) + 37),
                child: Stack(children: [
                  for (var k = 0; k < items.length; k++)
                    Positioned(
                      left: 32.0 * k,
                      child: GestureDetector(
                        onTap: () => setState(() => _i = k),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: k == i ? Colors.white : Colors.transparent, width: 2)),
                          child: ModelDisc(color: items[k].model.providerColor, label: items[k].model.label, size: 37),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              const FText('Prompts', size: 17, height: 22, weight: FontWeight.w700),
              const SizedBox(width: 8),
              FText('${items.length}', size: 15, height: 22, weight: FontWeight.w700, opacity: 0.4),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  for (var k = 0; k < items.length; k++)
                    GestureDetector(
                      onTap: () => setState(() => _i = k),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FGlass(
                          radius: BorderRadius.circular(18),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              ModelDisc(color: items[k].model.providerColor, label: items[k].model.label, size: 28),
                              const SizedBox(width: 10),
                              Expanded(child: FText(items[k].model.label, size: 15, height: 20, weight: FontWeight.w700, maxLines: 1)),
                              const SizedBox(width: 8),
                              FText(_hm(items[k].at), size: 14, height: 20, weight: FontWeight.w700, opacity: 0.6),
                            ]),
                            if (items[k].prompt.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              FText(items[k].prompt, size: 14, height: 20, weight: FontWeight.w500, opacity: 0.75, maxLines: 3),
                            ],
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}