import 'dart:ui';

import 'package:flutter/material.dart';

/// One subcategory (a content tag) and how many themes carry it.
class NavLeaf {
  final String label;
  final String tag;
  final int count;
  const NavLeaf(this.label, this.tag, this.count);
}

/// One top-level category in the side nav.
class NavGroup {
  final String label;
  final IconData icon;
  final List<NavLeaf> leaves;
  final int count;
  const NavGroup(this.label, this.icon, this.leaves, this.count);
}

/// v9.1.6 taxonomy (David: the minimum necessary, less is more). The R2
/// objects carry exactly these tags (qa/retag.py): one category tag plus
/// subcategory tags, plus format tags that never show here.
class CategoryTaxonomy {
  // v9.1.6b: searchable subjects (what people type), hand-checked against
  // what each R2 item depicts. Flat; Motion keeps Live / Stills.
  static const List<(String, IconData, String, List<String>)> groups = [
    ('Nature', Icons.forest_outlined, 'nature', []),
    ('Ocean', Icons.waves_rounded, 'ocean', []),
    ('Space', Icons.auto_awesome_outlined, 'space', []),
    ('City', Icons.location_city_outlined, 'city', []),
    ('Rain', Icons.water_drop_outlined, 'rain', []),
    ('Cozy', Icons.weekend_outlined, 'cozy', []),
    ('Fantasy', Icons.castle_outlined, 'fantasy', []),
    ('Abstract', Icons.blur_on_rounded, 'abstract', []),
  ];

  static const Map<String, String> _names = {'live wallpaper': 'Live', 'wallpaper': 'Stills'};

  static String title(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');

  /// A selection key: '' = All, 'g:<Group>' = a whole group, 't:<tag>' = one tag.
  static bool matches(String key, List<String> tags) {
    if (key.isEmpty) return true;
    final low = tags.map((t) => t.toLowerCase()).toSet();
    // v9.1.7 (#26): 't:<group tag>|<format tag>' = a subcategory (all must match).
    if (key.startsWith('t:')) return key.substring(2).split('|').every(low.contains);
    final g = groups.where((e) => 'g:${e.$1}' == key);
    if (g.isEmpty) return true;
    final e = g.first;
    return e.$3.isNotEmpty ? low.contains(e.$3) : e.$4.any(low.contains);
  }

  static String labelOf(String key) {
    if (key.isEmpty) return 'All';
    if (key.startsWith('g:')) return key.substring(2);
    final parts = key.substring(2).split('|');
    return parts.map((t) => _names[t] ?? (t == '4k' ? '4K' : title(t))).join(' · ');
  }

  /// v9.1.7 (#26): the subcategories every group cascades into: its live and
  /// still items, and its 4K items (the R2 objects carry these format tags).
  static const List<(String, String)> _formats = [('live wallpaper', 'Live'), ('wallpaper', 'Stills'), ('4k', '4K')];

  static List<NavGroup> build(List<List<String>> allTags) {
    final out = <NavGroup>[];
    for (final (label, icon, _, tags) in groups) {
      final leaves = <NavLeaf>[];
      for (final t in tags) {
        final n = allTags.where((ts) => ts.any((x) => x.toLowerCase() == t)).length;
        if (n > 0) leaves.add(NavLeaf(_names[t] ?? title(t), t, n));
      }
      final gt = groups.firstWhere((e) => e.$1 == label).$3;
      if (gt.isNotEmpty) {
        final sub = <NavLeaf>[];
        for (final (f, name) in _formats) {
          final n = allTags.where((ts) => matches('t:$gt|$f', ts)).length;
          if (n > 0) sub.add(NavLeaf(name, '$gt|$f', n));
        }
        // Only a real split: one format alone is the whole group again.
        if (sub.length > 1 || (sub.length == 1 && sub.first.count < allTags.where((ts) => matches('g:$label', ts)).length)) leaves.addAll(sub);
      }
      final total = allTags.where((ts) => matches('g:$label', ts)).length;
      if (total > 0) out.add(NavGroup(label, icon, leaves, total));
    }
    return out;
  }
}

/// visionOS browser-style sidebar (Figma 1:101) that floats OVER the content
/// (it never pushes the preview). Categories are a short list; a category's
/// subcategories cascade HORIZONTALLY into a second glass panel beside it.
class CategorySideNav extends StatefulWidget {
  final List<NavGroup> groups;
  final int total;
  final String selected;
  final ValueChanged<String> onSelected;
  final double width;
  final double? maxHeight;
  const CategorySideNav({super.key, required this.groups, required this.total, required this.selected, required this.onSelected, this.width = 168, this.maxHeight});

  @override
  State<CategorySideNav> createState() => _CategorySideNavState();
}

class _CategorySideNavState extends State<CategorySideNav> {
  String? _open;

  @override
  void initState() {
    super.initState();
    final s = widget.selected;
    for (final g in widget.groups) {
      if (s == 'g:${g.label}' || g.leaves.any((l) => s == 't:${l.tag}')) _open = g.label;
    }
  }

  static const white = Colors.white;
  Widget _count(int n, bool on) => Text('$n', style: TextStyle(fontSize: 12, color: white.withValues(alpha: on ? 1 : 0.8), fontFeatures: const [FontFeature.tabularFigures()]));

  Widget _row({required String label, IconData? icon, required int n, required bool on, required VoidCallback onTap, bool chevron = false, bool hi = false, Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: on || hi ? const Color(0x33FFFFFF) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                if (icon != null) ...[Icon(icon, size: 18, color: white), const SizedBox(width: 8)],
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: white))),
                _count(n, on),
                if (chevron) ...[const SizedBox(width: 4), Icon(Icons.chevron_right_rounded, size: 18, color: white.withValues(alpha: 0.8))],
              ]),
            ),
          ),
        ),
      );

  Widget _panel(Widget child, double w) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: w,
            constraints: BoxConstraints(maxHeight: widget.maxHeight ?? double.infinity),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: const Color(0xD018181E), borderRadius: BorderRadius.circular(24)),
            child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(mainAxisSize: MainAxisSize.min, children: [child])),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.selected;
    final open = widget.groups.where((g) => g.label == _open).firstOrNull;
    final main = _panel(
      Column(mainAxisSize: MainAxisSize.min, children: [
        _row(key: const ValueKey('nav-all'), label: 'All', n: widget.total, on: s.isEmpty, onTap: () => widget.onSelected('')),
        for (final g in widget.groups)
          _row(
            key: ValueKey('nav-${g.label}'),
            label: g.label,
            icon: g.icon,
            n: g.count,
            on: s == 'g:${g.label}' || g.leaves.any((l) => s == 't:${l.tag}'),
            hi: _open == g.label,
            chevron: g.leaves.isNotEmpty,
            onTap: () => g.leaves.isEmpty ? widget.onSelected('g:${g.label}') : setState(() => _open = _open == g.label ? null : g.label),
          ),
      ]),
      widget.width,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        main,
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: open == null
              ? const SizedBox(height: 0)
              : Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _panel(
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      _row(key: ValueKey('leaf-all-${open.label}'), label: 'All ${open.label}', n: open.count, on: s == 'g:${open.label}', onTap: () => widget.onSelected('g:${open.label}')),
                      for (final l in open.leaves)
                        _row(key: ValueKey('leaf-${l.tag}'), label: l.label, n: l.count, on: s == 't:${l.tag}', onTap: () => widget.onSelected('t:${l.tag}')),
                    ]),
                    130,
                  ),
                ),
        ),
      ],
    );
  }
}

/// v9.1.6: the central tier button ('Free' / 'Premium'). Swipe it up or
/// down (or tap it) to switch tier.
class TierSwitchPill extends StatelessWidget {
  final String label;
  final VoidCallback onSwitch;
  const TierSwitchPill({super.key, required this.label, required this.onSwitch});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label. Swipe up or down to switch',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSwitch,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0).abs() > 150) onSwitch();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: const Color(0xB318181E),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.unfold_more_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// v9.1.6c: the category nav pinned as a bar along the top of the pane
/// (visionOS browser, Figma 1:101): always visible, never moves the content.
/// One frosted strip of Title-Case buttons; scrolls sideways with edge fades.
class CategoryBar extends StatelessWidget {
  final List<NavGroup> groups;
  final int total;
  final String selected;
  final ValueChanged<String> onSelected;
  const CategoryBar({super.key, required this.groups, required this.total, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    // v9.1.7 (#26): subcategories cascade horizontally: the selected
    // group's subcategories open inline, right after it, as smaller chips.
    final items = <(String, String, int)>[('', 'All', total)];
    final subs = <String>{};
    for (final g in groups) {
      items.add(('g:${g.label}', g.label, g.count));
      final open = selected == 'g:${g.label}' || g.leaves.any((l) => selected == 't:${l.tag}');
      if (open) {
        for (final l in g.leaves) {
          items.add(('t:${l.tag}', l.label, l.count));
          subs.add('t:${l.tag}');
        }
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 44,
          color: const Color(0xB318181E),
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)], stops: [0, 0.05, 0.95, 1]).createShader(r),
            blendMode: BlendMode.dstIn,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              children: [
                for (final (k, label, _) in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Semantics(
                      button: true,
                      selected: selected == k,
                      label: label,
                      child: GestureDetector(
                        key: ValueKey('cat-$label'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelected(k),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(horizontal: subs.contains(k) ? 10 : 14),
                          margin: EdgeInsets.symmetric(vertical: subs.contains(k) ? 4 : 0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected == k ? const Color(0x40FFFFFF) : (subs.contains(k) ? const Color(0x1AFFFFFF) : Colors.transparent),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(label, style: TextStyle(fontSize: subs.contains(k) ? 13 : 15, fontWeight: selected == k ? FontWeight.w600 : FontWeight.w500, color: Colors.white)),
                        ),
                      ),
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
