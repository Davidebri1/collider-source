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

/// Category taxonomy derived from the catalogue's content tags (format and
/// resolution tags such as "mp4" or "720p" never appear here).
class CategoryTaxonomy {
  static const List<(String, IconData, List<String>)> groups = [
    ('Nature', Icons.forest_outlined, ['nature', 'forest', 'mountains', 'lake', 'desert', 'cave', 'snow']),
    ('Water', Icons.water_outlined, ['ocean', 'waves', 'water', 'rain']),
    ('Sky', Icons.cloud_outlined, ['clouds', 'sky', 'sunset', 'storm', 'fog']),
    ('Space', Icons.auto_awesome_outlined, ['space', 'stars']),
    ('City', Icons.location_city_outlined, ['city', 'night', 'neon']),
    ('Cozy', Icons.weekend_outlined, ['cozy', 'room', 'cat']),
    ('Fantasy', Icons.castle_outlined, ['fantasy', 'anime', 'castle']),
    ('Abstract', Icons.blur_on_rounded, ['abstract', 'minimal', 'gradient', 'dark']),
    ('Motion', Icons.movie_outlined, ['live wallpaper', 'wallpaper']),
  ];

  static const Map<String, String> _names = {'live wallpaper': 'Live', 'wallpaper': 'Stills'};

  static String title(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');

  /// A selection key: '' = All, 'g:<Group>' = a whole group, 't:<tag>' = one tag.
  static bool matches(String key, List<String> tags) {
    if (key.isEmpty) return true;
    final low = tags.map((t) => t.toLowerCase()).toSet();
    if (key.startsWith('t:')) return low.contains(key.substring(2));
    final g = groups.where((e) => 'g:${e.$1}' == key);
    if (g.isEmpty) return true;
    return g.first.$3.any(low.contains);
  }

  static String labelOf(String key) => key.isEmpty ? 'All' : (_names[key.substring(2)] ?? title(key.substring(2)));

  static List<NavGroup> build(List<List<String>> allTags) {
    final out = <NavGroup>[];
    for (final (label, icon, tags) in groups) {
      final leaves = <NavLeaf>[];
      for (final t in tags) {
        final n = allTags.where((ts) => ts.any((x) => x.toLowerCase() == t)).length;
        if (n > 0) leaves.add(NavLeaf(_names[t] ?? title(t), t, n));
      }
      final total = allTags.where((ts) => matches('g:$label', ts)).length;
      if (total > 0) out.add(NavGroup(label, icon, leaves, total));
    }
    return out;
  }
}

/// visionOS browser-style sidebar (Figma 1:101): a glass panel with a list of
/// categories, each expandable to its subcategories, every row with a count.
/// Built from ListTile and ExpansionTile.
class CategorySideNav extends StatelessWidget {
  final List<NavGroup> groups;
  final int total;
  final String selected;
  final ValueChanged<String> onSelected;
  final double width;
  final double? maxHeight;
  const CategorySideNav({super.key, required this.groups, required this.total, required this.selected, required this.onSelected, this.width = 168, this.maxHeight});

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    Widget count(int n, bool on) => Text('$n', style: TextStyle(fontSize: 12, color: white.withValues(alpha: on ? 1 : 0.8), fontFeatures: const [FontFeature.tabularFigures()]));
    Widget tile({required String key, required String label, IconData? icon, required int n, bool dense = false}) {
      final on = selected == key;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -3),
          contentPadding: EdgeInsets.only(left: dense ? 22 : 10, right: 10),
          minLeadingWidth: 0,
          horizontalTitleGap: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: Colors.transparent,
          selectedTileColor: const Color(0x33FFFFFF),
          selected: on,
          leading: icon == null ? null : Icon(icon, size: 18, color: white),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: dense ? 13 : 14, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: white)),
          trailing: count(n, on),
          onTap: () => onSelected(key),
        ),
      );
    }

    final list = ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      children: [
        tile(key: '', label: 'All', n: total),
        for (final g in groups)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent, splashColor: Colors.transparent, listTileTheme: const ListTileThemeData(dense: true)),
            child: ExpansionTile(
              key: PageStorageKey('nav-${g.label}'),
              initiallyExpanded: selected == 'g:${g.label}' || g.leaves.any((l) => selected == 't:${l.tag}'),
              tilePadding: const EdgeInsets.only(left: 16, right: 4),
              dense: true,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -3),
              iconColor: white,
              collapsedIconColor: white,
              shape: const Border(),
              collapsedShape: const Border(),
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected('g:${g.label}'),
                child: Row(children: [
                  Expanded(child: Text(g.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: selected == 'g:${g.label}' ? FontWeight.w600 : FontWeight.w500, color: white))),
                  count(g.count, selected == 'g:${g.label}'),
                ]),
              ),
              children: [for (final l in g.leaves) tile(key: 't:${l.tag}', label: l.label, n: l.count, dense: true)],
            ),
          ),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: width,
          constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity),
          decoration: BoxDecoration(
            color: const Color(0xD018181E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
          ),
          child: Material(type: MaterialType.transparency, child: list),
        ),
      ),
    );
  }
}
