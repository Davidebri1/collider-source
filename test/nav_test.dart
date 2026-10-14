import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collider_flutter/core/vision/category_nav.dart';
void main() {
  testWidgets('nav', (t) async {
    final g = CategoryTaxonomy.build([['city','night'],['ocean'],['live wallpaper']]);
    await t.pumpWidget(MaterialApp(home: Stack(children: [Positioned(left: 8, top: 100, child: CategorySideNav(width: 200, maxHeight: 500, groups: g, total: 3, selected: '', onSelected: (_) {}))])));
    await t.tap(find.text('City'));
    await t.pumpAndSettle();
  });
}
