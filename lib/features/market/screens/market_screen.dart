import 'package:flutter/material.dart';
import '../../../core/api/media_gen.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/work_surface.dart';
import '../../../models/media_specs.dart';
import '../../../models/theme_def.dart';
import '../../mediagen/media_view.dart';
import '../../theme/theme_living_media.dart';

/// Discover Market (map row 21, Video Platforms on visionOS 203:5891), with
/// the source's content and behaviour (screens/MarketScreen.tsx): the hero
/// is the featured theme still, the shelf and the photographic grid are the
/// catalog's stills (PHOTO_SEED), the kinds are the source's Stills /
/// Templates / Cinematic / Night as the bottom tab ornament, a tile opens
/// full size with Remix, and the market's own composer generates an image
/// with the source's keyless FLUX route. v8.3: the invented prompt cards
/// (Term Life Plan, Heat Pump Sizing, Family Recipes; not in the source)
/// are gone. The source's Supabase feed is dead (D62), so the market shows
/// the catalog stills and this session's own generations.
class MarketScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String prompt) onUsePrompt;
  /// One quiet line (e.g. a generation that cannot run on this link).
  final void Function(String text)? onNotice;

  const MarketScreen({super.key, required this.onClose, required this.onUsePrompt, this.onNotice});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _Tile {
  final String id;
  final String title;
  final String src; // theme media path or data: URI
  final bool generated;
  const _Tile(this.id, this.title, this.src, {this.generated = false});
}

class _MarketScreenState extends State<MarketScreen> {
  static const _kinds = ['Stills', 'Templates', 'Cinematic', 'Night'];
  int _kind = 0;
  final List<_Tile> _generated = [];
  final TextEditingController _ctrl = TextEditingController();
  bool _busy = false;
  _Tile? _open;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// MarketScreen.tsx PHOTO_SEED: the catalog's stills, preferred ids first.
  List<_Tile> _seed() {
    const prefer = ['twilight', 'sanctuary', 'blade', 'cabin', 'transit', 'alley4', 'alley3', 'ocean', 'garden', 'neoncity', 'observatory', 'rainfall', 'dunehall', 'starbridge', 'twinsuns', 'deck'];
    final themes = WallpaperCatalog.freeThemes;
    final out = <_Tile>[];
    final seen = <String>{};
    for (final id in prefer) {
      for (final t in themes) {
        if (t.id.toLowerCase().contains(id) && seen.add(t.id)) out.add(_Tile('photo-${t.id}', t.name, t.stillPath ?? t.assetPath));
      }
    }
    for (final t in themes) {
      if (out.length >= 18) break;
      if (seen.add(t.id)) out.add(_Tile('photo-${t.id}', t.name, t.stillPath ?? t.assetPath));
    }
    return out;
  }

  List<_Tile> _masonry(List<_Tile> seed) {
    final merged = [..._generated, ...seed];
    return switch (_kinds[_kind]) {
      'Templates' => merged.take(10).toList(),
      'Cinematic' => [for (var i = 0; i < merged.length; i++) if (i % 2 == 0) merged[i]],
      'Night' => [for (var i = 0; i < merged.length; i++) if (i % 3 != 1) merged[i]],
      _ => merged,
    };
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await MediaGen.instance.generate('img/flux-free', text, const GenFlags(ar: '9:16'));
      if (!mounted) return;
      final t = _Tile('gen_local_${DateTime.now().millisecondsSinceEpoch}', text, r.url, generated: true);
      setState(() {
        _generated.insert(0, t);
        _open = t;
        _ctrl.clear();
      });
    } catch (_) {
      // The source's keyless route now refuses (Pollinations 402, D61).
      widget.onNotice?.call("Can't run on this link");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _img(_Tile t, {BoxFit fit = BoxFit.cover}) =>
      t.generated ? GenMediaView(url: t.src, kind: 'image', fit: fit) : ThemeImage(t.src, fit: fit);

  @override
  Widget build(BuildContext context) {
    final seed = _seed();
    if (seed.isEmpty && _generated.isEmpty) return const SizedBox.shrink();
    final featured = seed.firstWhere((t) => RegExp('neon|alley4|blade|sanctuary', caseSensitive: false).hasMatch(t.id + t.title), orElse: () => seed.isNotEmpty ? seed.first : _generated.first);
    final shelf = [..._generated.take(4), ...seed.where((t) => t.id != featured.id).take(8)];
    final grid = _masonry(seed).where((t) => t.id != featured.id).toList();
    return Stack(
      children: [
        VWorkSurface(
          hug: true,
          onClose: widget.onClose,
          tabs: _kinds,
          activeTab: _kind,
          onTab: (i) => setState(() => _kind = i),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: VFadeScroll(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hero(featured),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.md, VSpace.md, VSpace.xs),
                        child: Text(_kinds[_kind], style: VType.callout(weight: FontWeight.w600)),
                      ),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: VSpace.md),
                          itemCount: shelf.length,
                          separatorBuilder: (_, __) => const SizedBox(width: VSpace.xs),
                          itemBuilder: (_, i) => VPress(
                            tooltip: shelf[i].title,
                            onTap: () => setState(() => _open = shelf[i]),
                            child: ClipRRect(borderRadius: BorderRadius.circular(VRadius.sm), child: SizedBox(width: 150, height: 92, child: _img(shelf[i]))),
                          ),
                        ),
                      ),
                      // Flush photographic grid (PhotoMasonry), second beat.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.md, VSpace.md, VSpace.sm),
                        child: LayoutBuilder(builder: (ctx, c) {
                          final w = (c.maxWidth - VSpace.xs) / 2;
                          return Wrap(spacing: VSpace.xs, runSpacing: VSpace.xs, children: [
                            for (var i = 0; i < grid.length; i++)
                              VPress(
                                tooltip: grid[i].title,
                                onTap: () => setState(() => _open = grid[i]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(VRadius.sm),
                                  child: SizedBox(width: w, height: i % 3 == 0 ? w * 1.25 : w * 0.8, child: _img(grid[i])),
                                ),
                              ),
                          ]);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              // v9.1.4 (playtest #12): no second input; the app has one composer.
            ],
          ),
        ),
        if (_open != null) Positioned.fill(child: _exploder(_open!)),
      ],
    );
  }

  Widget _hero(_Tile t) {
    // v9.1.4 (playtest #12): no painted gradient and nothing on the media;
    // the title and actions sit below the picture.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          SizedBox(height: 200, child: ClipRRect(borderRadius: BorderRadius.circular(VRadius.sm), child: _img(t))),
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.sm, VSpace.md, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.title()),
                const SizedBox(height: VSpace.sm),
                Row(children: [
                  VButton(label: 'Open', icon: Icons.play_arrow_rounded, dense: true, onTap: () => setState(() => _open = t)),
                  const SizedBox(width: VSpace.xs),
                  VButton(label: 'Remix', icon: Icons.autorenew_rounded, dense: true, onTap: () => _remix(t)),
                ]),
              ],
            ),
          ),
        ],
    );
  }

  void _remix(_Tile t) {
    // MarketScreen.tsx onRemix: the item's prompt goes into the composer.
    // v9.1.4: no market composer any more, so Remix runs the item's prompt.
    _ctrl.text = t.title;
    setState(() => _open = null);
    _submit();
  }

  /// MediaExploder: the asset full size over a blurred scrim, with Remix.
  Widget _exploder(_Tile t) {
    return Stack(fit: StackFit.expand, children: [
      VScrim(onTap: () => setState(() => _open = null)),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(VSpace.md, 56, VSpace.md, 96),
          child: Column(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(VRadius.card), child: _img(t, fit: BoxFit.contain))),
            const SizedBox(height: VSpace.sm),
            VGlass(
              material: VMaterial.elevated,
              radius: VRadius.full,
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                VCircleButton(icon: Icons.autorenew_rounded, size: 44, tooltip: 'Remix', onTap: () => _remix(t)),
                VCircleButton(icon: Icons.close_rounded, size: 44, tooltip: 'Close', onTap: () => setState(() => _open = null)),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}
