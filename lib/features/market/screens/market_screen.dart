import 'package:flutter/material.dart';
import '../../../core/api/media_gen.dart';
import '../../../core/vision/vision_kit.dart';
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

  /// The Discover feed picked on the side nav: stills, templates or night.
  final String feed;

  const MarketScreen({super.key, required this.onClose, required this.onUsePrompt, this.onNotice, this.feed = 'stills'});

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
  static const _kinds = ['Stills', 'Templates', 'Night']; // fits the pane, no clipped chip
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
    _kind = switch (widget.feed) { 'templates' => 1, 'night' => 2, _ => 0 };
    final shelf = [..._generated.take(4), ...seed.take(10)];
    final grid = _masonry(seed);
    // v9.1.7 (#126): David's rule wins over the literal copy: Discover is a
    // centred floating pane the width of the other panes (Smart Gen), never
    // full width. Inside it, Grok Imagine's content and order are unchanged.
    final paneW = (MediaQuery.sizeOf(context).width * 0.72).clamp(280.0, 520.0);
    // v9.1.7 (#18/#19): a literal copy of the Grok Imagine feed in black:
    // full-bleed black stage, floating top bar over the scrolling content,
    // "Create from template" portrait row, then the flush two-column grid
    // with hairline gaps and square corners. No promo banner (#18). Labels
    // stay below images (David: nothing on top of an image). The feeds are
    // on the overlaying side nav (#24); the app keeps its one composer.
    final pane = Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        Positioned.fill(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: 64)),
              if (_kind != 2) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Text('Create from template', style: VType.callout(weight: FontWeight.w600, color: Colors.white70)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: shelf.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => VPress(
                        onTap: () => _remix(shelf[i]),
                        child: SizedBox(
                          width: 132,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 132, height: 196, child: _img(shelf[i]))),
                            const SizedBox(height: 6),
                            Text(shelf[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.caption(color: Colors.white)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 3, crossAxisSpacing: 3, childAspectRatio: 0.67),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => VPress(onTap: () => setState(() => _open = grid[i]), child: _img(grid[i])),
                  childCount: grid.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
        // Floating top bar, as in Imagine: content scrolls under a black fade.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: Container(
              height: 84,
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE6000000), Color(0x00000000)])),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 10,
          child: SizedBox(
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(999)),
                child: Text(_kind == 0 ? 'Discover' : _kinds[_kind], style: VType.callout(weight: FontWeight.w600, color: Colors.white)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: VPress(
                  tooltip: 'Close',
                  onTap: widget.onClose,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: Color(0x26FFFFFF), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 40, 0, 12),
            child: Center(
              child: SizedBox(
                width: paneW,
                child: DecoratedBox(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(VRadius.xl), boxShadow: VElev.e6),
                  child: ClipRRect(borderRadius: BorderRadius.circular(VRadius.xl), child: pane),
                ),
              ),
            ),
          ),
        ),
        if (_open != null) Positioned.fill(child: _exploder(_open!)),
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
