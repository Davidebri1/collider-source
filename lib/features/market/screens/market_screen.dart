import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/api/media_gen.dart';
import '../../../core/vision/cpane.dart';
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

  /// The Discover side-nav pick (PRD Surfaces): home, search or library.
  final String feed;

  const MarketScreen({super.key, required this.onClose, required this.onUsePrompt, this.onNotice, this.feed = 'home'});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _Tile {
  final String id;
  final String title;
  final String src; // theme media path or data: URI
  final bool generated;
  final List<String> tags;
  const _Tile(this.id, this.title, this.src, {this.generated = false, this.tags = const []});
}

class _MarketScreenState extends State<MarketScreen> {
  // PRD R27 / Surfaces (Discover Market), edited by David Oct 15: the side
  // nav is Search and Library. Home (nothing picked) is the Imagine order: a
  // row of pictures, then the two-column feed. No looks, no template shelf.
  String _q = '';
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
        if (t.id.toLowerCase().contains(id) && seen.add(t.id)) out.add(_Tile('photo-${t.id}', t.name, t.stillPath ?? t.assetPath, tags: t.tags));
      }
    }
    for (final t in themes) {
      if (out.length >= 18) break;
      if (seen.add(t.id)) out.add(_Tile('photo-${t.id}', t.name, t.stillPath ?? t.assetPath, tags: t.tags));
    }
    return out;
  }

  List<_Tile> _feed(List<_Tile> seed) {
    var merged = widget.feed == 'library' ? [..._generated] : [..._generated, ...seed];
    if (widget.feed == 'search' && _q.isNotEmpty) merged = [for (final t in merged) if (t.title.toLowerCase().contains(_q.toLowerCase())) t];
    return merged;
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
    final feed = widget.feed;
    final grid = _feed(seed);
    final home = feed != 'library' && feed != 'search';
    // v9.1.7 (#126): Discover is a centred floating pane (CPane).
    // PRD R27: pictures only, in the Imagine order. Labels stay below images.
    final pane = Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        Positioned.fill(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: 64)),
              if (home) ...[
                // 1. A row of pictures.
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: math.min(seed.length, 10),
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => VPress(
                        onTap: () => setState(() => _open = seed[i]),
                        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 88, height: 132, child: _img(seed[i]))),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
              if (feed == 'library' && grid.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
                    child: Text('Images you make or save show here', textAlign: TextAlign.center, style: VType.callout(color: Colors.white70)),
                  ),
                ),
              // 2. The two-column feed.
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
                child: feed == 'search'
                    ? SizedBox(
                        width: 200,
                        child: TextField(
                          autofocus: true,
                          onChanged: (v) => setState(() => _q = v.trim()),
                          cursorColor: Colors.white,
                          style: VType.callout(weight: FontWeight.w600, color: Colors.white),
                          decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: 'Search', hintStyle: VType.callout(color: Colors.white54)),
                        ),
                      )
                    : Text(switch (feed) { 'library' => 'Library', _ => 'Discover' }, style: VType.callout(weight: FontWeight.w600, color: Colors.white)),
              ),
              // v9.1.7: no close circle (David: no on-screen close controls;
              // tap outside or swipe closes), so the general rule wins here too.
            ]),
          ),
        ),
      ],
    );
    return Stack(
      children: [
        CPane(child: pane),
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
