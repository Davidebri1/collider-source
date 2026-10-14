// Map row 17 (Image/Video/Music Gen Options Overlay/Expansion), Figma
// Vision OS Design System 417:15864, stacked for a phone: the big media card
// with floating pills and a dots pager (one dot per selected model), the dark
// detail panel (title, divider, detail lines, the task row with the model's
// badge, outlined option tiles), and the total pill with the red action.
// Every value comes from the source's specs (media_specs.dart); each choice
// shows its credit price, as the source composer does.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/vision/vision_kit.dart';
import '../../models/media_specs.dart';
import '../../models/model_def.dart';
import '../theme/theme_living_media.dart';
import 'gen_settings.dart';
import 'media_view.dart';

class GenOptionsSheet extends StatefulWidget {
  final ModelCategory category;
  final List<ModelDef> models;
  final GenSettings settings;
  final List<String> references;
  final ValueChanged<List<String>> onReferences;
  /// Shown in the media card: the latest result for this category, or the
  /// current wallpaper's poster when there is none yet.
  final String? previewUrl;
  final String posterFallback;
  final VoidCallback onChanged;
  final VoidCallback onGenerate;
  final VoidCallback onClose;

  const GenOptionsSheet({
    super.key,
    required this.category,
    required this.models,
    required this.settings,
    required this.references,
    required this.onReferences,
    required this.previewUrl,
    required this.posterFallback,
    required this.onChanged,
    required this.onGenerate,
    required this.onClose,
  });

  @override
  State<GenOptionsSheet> createState() => _GenOptionsSheetState();
}

class _Opt {
  final String key;
  final IconData icon;
  final String label;
  final String value;
  final List<(String, String)> choices; // (value, shown)
  final void Function(String) apply;
  /// Settings override used to price a choice (null: the choice is not billed).
  final GenFlags Function(String)? price;
  const _Opt(this.key, this.icon, this.label, this.value, this.choices, this.apply, [this.price]);
}

class _GenOptionsSheetState extends State<GenOptionsSheet> {
  int _page = 0;
  String? _open;

  GenSettings get s => widget.settings;
  ModelCategory get cat => widget.category;

  void _set(void Function() f) {
    setState(f);
    s.fitTo(cat, widget.models);
    widget.onChanged();
  }

  List<_Opt> _opts() {
    final ids = widget.models.map((m) => m.id).toList();
    switch (cat) {
      case ModelCategory.image:
        final o = intersectImageOptions(ids);
        final ratios = (o != null && o.aspectRatios.isNotEmpty) ? o.aspectRatios : const ['9:16', '4:5', '1:1', '16:9'];
        int pf(String r) {
          final p = r.split(':').map(int.parse).toList();
          return p[0] < p[1] ? 0 : (p[0] == p[1] ? 1 : 2);
        }
        final sorted = [...ratios]..sort((a, b) => pf(a) - pf(b));
        return [
          _Opt('ar', Icons.crop_portrait_rounded, 'Aspect ratio', s.ar, [for (final r in sorted) (r, r)], (v) => s.ar = v),
          if (o != null && o.resolutions.isNotEmpty)
            _Opt('res', Icons.high_quality_outlined, 'Resolution', s.resolution ?? o.resolutions.first, [for (final r in o.resolutions) (r, r)], (v) => s.resolution = v),
          // Not Icons.auto_awesome_outlined: sparkle-shaped glyphs are banned. Quality is
          // a fidelity setting, so it reads as a gauge.
          _Opt('quality', Icons.speed_rounded, 'Quality', _q(s.quality), const [('standard', 'Standard'), ('hd', 'HD'), ('ultra', 'Ultra')], (v) => s.quality = v,
              (v) => GenFlags(task: s.task, ar: s.ar, quality: v, count: 1)),
          _Opt('style', Icons.palette_outlined, 'Style', _style(s.style), const [('neutral', 'Neutral'), ('photorealistic', 'Realistic'), ('3d-render', '3D Render'), ('anime', 'Anime'), ('cyberpunk', 'Cyberpunk')], (v) => s.style = v),
        ];
      case ModelCategory.video:
        final o = intersectVideoOptions(ids);
        final durs = durationChoicesFor(widget.models);
        return [
          _Opt('ar', Icons.crop_portrait_rounded, 'Aspect ratio', s.ar, [for (final r in (o?.aspectRatios ?? const ['9:16', '16:9'])) (r, r)], (v) => s.ar = v),
          _Opt('dur', Icons.timer_outlined, 'Duration', '${s.duration}s', [for (final d in durs) ('$d', '${d}s')], (v) => s.duration = int.parse(v),
              (v) => GenFlags(task: s.task, ar: s.ar, quality: s.quality, duration: int.parse(v))),
          _Opt('res', Icons.high_quality_outlined, 'Resolution', s.quality.toUpperCase(), [for (final r in (o?.resolutions ?? const ['720p'])) (r, r.toUpperCase())], (v) => s.quality = v,
              (v) => GenFlags(task: s.task, ar: s.ar, quality: v, duration: s.duration)),
          _Opt('motion', Icons.waves_rounded, 'Motion', _cap(s.motion), const [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')], (v) => s.motion = v),
        ];
      case ModelCategory.audio:
        final caps = unionCapabilities(widget.models);
        final speech = s.task == 'text-to-speech' || s.task == 'dubbing';
        return [
          _Opt('len', Icons.timer_outlined, 'Length', formatDuration(s.duration), const [('15', '15s'), ('30', '30s'), ('60', '1m'), ('120', '2m'), ('180', '3m')], (v) => s.duration = int.parse(v),
              (v) => GenFlags(task: s.task, duration: int.parse(v))),
          if (speech && caps.voices.isNotEmpty)
            _Opt('voice', Icons.record_voice_over_outlined, 'Voice', s.voice ?? caps.voices.first, [for (final v in caps.voices) (v, v)], (v) => s.voice = v),
          _Opt('vocals', Icons.mic_none_rounded, 'Vocals', s.vocals == 'vocal' ? 'Vocal track' : 'Instrumental', const [('vocal', 'Vocal track'), ('instrumental', 'Instrumental')], (v) => s.vocals = v),
          _Opt('bitrate', Icons.equalizer_rounded, 'Bitrate', s.bitrate == 'high' ? '320 kbps' : '128 kbps', const [('standard', '128 kbps'), ('high', '320 kbps')], (v) => s.bitrate = v),
          if (caps.outputFormats.isNotEmpty)
            _Opt('format', Icons.audio_file_outlined, 'Format', s.format == 'wav' ? 'WAV lossless' : s.format.toUpperCase(), [for (final f in caps.outputFormats) (f, f == 'wav' ? 'WAV lossless' : f.toUpperCase())], (v) => s.format = v),
        ];
      default:
        return const [];
    }
  }

  static String _cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
  static String _q(String v) => switch (v) { 'hd' => 'HD', 'ultra' => 'Ultra', _ => 'Standard' };
  static String _style(String v) => switch (v) { 'photorealistic' => 'Realistic', '3d-render' => '3D Render', 'neutral' => 'Neutral', _ => _cap(v) };

  Future<void> _attach() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
      if (r == null) return;
      final uris = [
        for (final f in r.files)
          if (f.bytes != null) 'data:image/${(f.extension ?? 'png').toLowerCase() == 'jpg' ? 'jpeg' : (f.extension ?? 'png').toLowerCase()};base64,${base64Encode(f.bytes!)}',
      ];
      widget.onReferences([...widget.references, ...uris]);
      setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final models = widget.models;
    final page = models.isEmpty ? 0 : _page.clamp(0, models.length - 1);
    final m = models.isEmpty ? null : models[page];
    final flags = s.flags(cat);
    final total = costOfAll(models, flags);
    final cost = m == null ? null : costOf(m, flags);
    final tasks = tasksForCategory(cat);
    final task = taskById(s.task);
    final opts = _opts();
    final open = opts.where((o) => o.key == _open).firstOrNull;
    final size = MediaQuery.sizeOf(context);
    final w = size.width.clamp(0.0, 560.0) - 2 * VSpace.md;

    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: widget.onClose),
        SafeArea(
          child: Stack(children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.md, VSpace.md, 84),
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _mediaCard(w, models.length, page),
                    const SizedBox(height: VSpace.sm),
                    _panel(m, cost, task, tasks, opts, open, total, flags),
                  ],
                ),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 8, child: Center(child: _totalPill(total))),
          ]),
        ),
      ],
    );
  }

  Widget _pill({required IconData icon, required String label, required VoidCallback onTap}) => VPress(
        onTap: onTap,
        child: VGlass(
          material: VMaterial.elevated,
          radius: VRadius.full,
          padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: VColors.textPrimary),
            const SizedBox(width: 8),
            Text(label, style: VType.callout(weight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _mediaCard(double w, int pages, int page) {
    final h = (w * 0.62).clamp(180.0, 320.0);
    final refs = widget.references;
    final supportsRefs = cat != ModelCategory.audio;
    return SizedBox(
      height: h + 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 22,
            height: h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(VRadius.card),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(VRadius.card),
                  border: Border.all(color: VColors.borderHeavy, width: 0.6),
                ),
                child: refs.isNotEmpty
                    ? GenMediaView(url: refs.last, kind: 'image')
                    : (widget.previewUrl != null
                        ? GenMediaView(url: widget.previewUrl!, kind: cat == ModelCategory.video ? 'video' : (cat == ModelCategory.audio ? 'audio' : 'image'))
                        : ThemeImage(widget.posterFallback, fit: BoxFit.cover)),
              ),
            ),
          ),
          // Floating pills over the top edge (Figma: Favourite / Share).
          if (supportsRefs)
            Positioned(
              left: 18,
              top: 0,
              child: _pill(icon: Icons.add_photo_alternate_outlined, label: refs.isEmpty ? 'Reference' : 'Reference ${refs.length}', onTap: _attach),
            ),
          Positioned(
            right: 18,
            top: 0,
            child: VCircleButton(icon: Icons.close_rounded, size: 44, floating: true, tooltip: 'Close', onTap: widget.onClose),
          ),
          // Dots pager: one per selected model.
          if (pages > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: -14,
              child: Center(
                child: VGlass(
                  material: VMaterial.elevated,
                  radius: VRadius.full,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < pages; i++)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _page = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: i == page ? const Color(0xFFE11D48) : Colors.white),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel(ModelDef? m, CostBreakdown? cost, TaskDef? task, List<TaskDef> tasks, List<_Opt> opts, _Opt? open, int total, GenFlags flags) {
    final spec = m == null ? null : _specLine(m);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 48),
          decoration: BoxDecoration(
            color: const Color(0xF0191919),
            borderRadius: BorderRadius.circular(VRadius.card),
            border: Border.all(color: VColors.borderLight, width: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(cat.label, style: VType.title2().copyWith(height: 1.2)),
              Text(m?.label ?? '', style: VType.title2().copyWith(height: 1.2)),
              const SizedBox(height: VSpace.sm),
              Container(height: 1.5, color: Colors.white),
              const SizedBox(height: VSpace.sm),
              if (m != null) ...[
                Row(children: [
                  Expanded(child: Text(m.provider, style: VType.callout(weight: FontWeight.w700).copyWith(fontSize: 14))),
                  // Not Icons.star_border_rounded: star glyphs are banned. The tier is a rank,
                  // so it reads as a label chip.
                  Text(TierInfo.all[m.tier]!.label,
                      style: VType.callout(weight: FontWeight.w600)
                          .copyWith(color: TierInfo.all[m.tier]!.color)),
                  const SizedBox(width: 6),
                ]),
                const SizedBox(height: 4),
                if (spec != null) Text(spec, style: VType.footnote()),
                const SizedBox(height: 2),
                if (cost != null) Text('${cost.credits} credit${cost.credits == 1 ? '' : 's'}${cost.basis.isEmpty ? '' : ' · ${cost.basis}'}', style: VType.footnote()),
              ],
              const SizedBox(height: VSpace.lg),
              // Task row (Figma: "Room in a rental unit hosted by Jamie" + badge).
              VPress(
                onTap: () => setState(() => _open = _open == 'task' ? null : 'task'),
                child: Row(children: [
                  Expanded(child: Text(task?.label ?? '', style: VType.headline().copyWith(fontSize: 19, height: 1.25))),
                  if (m != null) _badge(m),
                ]),
              ),
              if (_open == 'task') ...[
                const SizedBox(height: VSpace.sm),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in tasks)
                    Opacity(
                      opacity: t.routable ? 1 : 0.32,
                      child: VChip(
                        label: t.label,
                        selected: t.id == s.task,
                        onTap: t.routable ? () => _set(() => s.task = t.id) : null,
                      ),
                    ),
                ]),
              ],
              const SizedBox(height: VSpace.lg),
              LayoutBuilder(builder: (ctx, c) {
                const gap = 10.0;
                final tw = (c.maxWidth - 2 * gap) / 3;
                return Wrap(spacing: gap, runSpacing: gap, children: [
                  for (final o in opts) SizedBox(width: tw, child: _tile(o)),
                ]);
              }),
              if (open != null) ...[
                const SizedBox(height: VSpace.sm),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final (v, shown) in open.choices)
                    VChip(
                      label: open.price == null ? shown : '$shown · ${costOfAll(widget.models, open.price!(v))}',
                      selected: _isOn(open, v),
                      onTap: () => _set(() => open.apply(v)),
                    ),
                ]),
              ],
            ],
          ),
        ),
      ],
    );
  }


  // Total pill with the red action (Figma: "£978 total / July 7-11" + Reserve),
  // pinned over the panel's foot so Generate is always on screen.
  Widget _totalPill(int total) => VGlass(
              material: VMaterial.elevated,
              radius: VRadius.full,
              padding: const EdgeInsets.fromLTRB(26, 8, 8, 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '$total', style: VType.title2().copyWith(height: 1.1)),
                    TextSpan(text: ' credits', style: VType.callout(color: VColors.textSecondary)),
                  ])),
                  Text(_totalBasis(), style: VType.footnote(color: VColors.textPrimary)),
                ]),
                const SizedBox(width: 18),
                _GenerateButton(onTap: widget.onGenerate),
              ]),
            );

  bool _isOn(_Opt o, String v) => switch (o.key) {
        'ar' => s.ar == v,
        'res' => cat == ModelCategory.video ? s.quality == v : s.resolution == v,
        'quality' => s.quality == v,
        'style' => s.style == v,
        'dur' || 'len' => '${s.duration}' == v,
        'motion' => s.motion == v,
        'voice' => s.voice == v,
        'vocals' => s.vocals == v,
        'bitrate' => s.bitrate == v,
        'format' => s.format == v,
        _ => false,
      };

  String _totalBasis() {
    final n = widget.models.length;
    final models = '$n model${n == 1 ? '' : 's'}';
    return switch (cat) {
      ModelCategory.video => '$models · ${s.duration}s · ${s.quality}',
      ModelCategory.image => '$models · ${s.ar}',
      ModelCategory.audio => '$models · ${formatDuration(s.duration)}',
      _ => models,
    };
  }

  String? _specLine(ModelDef m) {
    final i = kImageSpecs[m.id];
    if (i != null) {
      final parts = <String>[
        if (i.aspectRatios.isNotEmpty) '${i.aspectRatios.length} ratios',
        if (i.resolutions.isNotEmpty) i.resolutions.join(' / '),
        if (i.maxReferences > 0) 'up to ${i.maxReferences} references',
      ];
      return parts.isEmpty ? null : parts.join(' • ');
    }
    final v = kVideoSpecs[m.id];
    if (v != null) {
      return [
        '${v.durations.first}–${v.durations.last}s',
        v.resolutions.join(' / '),
        if (v.generatesAudio) 'audio',
      ].join(' • ');
    }
    final c = capabilitiesFor(m);
    if (cat == ModelCategory.audio) return c.outputFormats.map((f) => f.toUpperCase()).join(' / ');
    return null;
  }

  Widget _badge(ModelDef m) => Container(
        width: 52,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: VElev.e2,
        ),
        alignment: Alignment.center,
        child: VAvatar(label: m.label, color: m.providerColor, size: 34),
      );

  Widget _tile(_Opt o) {
    final on = _open == o.key;
    return VPress(
      onTap: () => setState(() => _open = on ? null : o.key),
      child: Container(
        height: 118,
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 10),
        decoration: BoxDecoration(
          color: on ? VColors.fillCell : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: on ? 0.95 : 0.8), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(o.icon, size: 20, color: VColors.textPrimary),
            const Spacer(),
            Text(o.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w600).copyWith(fontSize: 13)),
            Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w400, color: VColors.textSecondary).copyWith(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _GenerateButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GenerateButton({required this.onTap});
  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFD7385E), borderRadius: BorderRadius.circular(VRadius.full)),
            child: Text('Generate', style: VType.body(weight: FontWeight.w600)),
          ),
        ),
      );
}
