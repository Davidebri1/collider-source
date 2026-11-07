import 'package:flutter/material.dart';

import 'sg_model.dart';

/// Photographic object on a board. Textures are the CC0 files in ASSETS.md.
/// The shape (open pages, folder tab, album mats, frame) is how those
/// photographs are placed. It is not a flat colour panel.

Widget sgBoardFace(SgBoard board) {
  final kind = board.kind;
  final photo = AssetImage(sgBoardAsset(kind));
  return switch (kind) {
    SgBoardKind.roundTable => Stack(fit: StackFit.expand, children: [
        const Image(image: AssetImage('assets/smartgen/desk.jpg'), fit: BoxFit.cover),
        Center(child: AspectRatio(aspectRatio: 1, child: ClipOval(child: Image(image: photo, fit: BoxFit.cover)))),
      ]),
    SgBoardKind.nightStand => Stack(fit: StackFit.expand, children: [
        const Image(image: AssetImage('assets/smartgen/desk.jpg'), fit: BoxFit.cover),
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.62,
            heightFactor: 0.46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(0, 8))],
                image: DecorationImage(image: photo, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ]),
    SgBoardKind.table => _furniture(photo, width: 0.84, height: 0.68, edge: 10),
    SgBoardKind.longTable => _furniture(photo, width: 0.94, height: 0.34, edge: 6),
    SgBoardKind.coffeeTable => _furniture(photo, width: 0.58, height: 0.28, edge: 8),
    SgBoardKind.longBench => _furniture(photo, width: 0.94, height: 0.2, edge: 0),
    SgBoardKind.whiteboardPlain => Stack(fit: StackFit.expand, children: [
        Image(image: photo, fit: BoxFit.cover),
        Center(child: FractionallySizedBox(widthFactor: 0.9, heightFactor: 0.8, child: _paperSheet())),
      ]),
    SgBoardKind.whiteboardLanes || SgBoardKind.kanban => Stack(fit: StackFit.expand, children: [
        Image(image: photo, fit: BoxFit.cover),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 28, 10, 12),
          child: Row(children: [
            for (final title in board.orderedLists.map((l) => l.title).take(3))
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    border: Border.all(color: const Color(0x55333333)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(title, style: const TextStyle(color: Color(0xFF1C1B19), fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    SgBoardKind.calendar => Stack(fit: StackFit.expand, children: [
        Image(image: photo, fit: BoxFit.cover),
        Center(child: FractionallySizedBox(widthFactor: 0.86, heightFactor: 0.72, child: _paperSheet(child: _monthGrid()))),
      ]),
    SgBoardKind.charts => Stack(fit: StackFit.expand, children: [
        Image(image: photo, fit: BoxFit.cover),
        Center(child: FractionallySizedBox(widthFactor: 0.8, heightFactor: 0.55, child: _paperSheet(child: _bars(board)))),
      ]),
    _ => Image(image: photo, fit: BoxFit.cover, filterQuality: FilterQuality.high),
  };
}

/// A tabletop on the desk floor, so the piece reads as furniture rather than a full-bleed texture.
Widget _furniture(AssetImage photo, {required double width, required double height, required double edge}) {
  return Stack(fit: StackFit.expand, children: [
    const Image(image: AssetImage('assets/smartgen/desk.jpg'), fit: BoxFit.cover),
    Center(
      child: FractionallySizedBox(
        widthFactor: width,
        heightFactor: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: edge <= 0 ? null : Border.all(color: const Color(0xFF24160E), width: edge),
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 10))],
            image: DecorationImage(image: photo, fit: BoxFit.cover),
          ),
        ),
      ),
    ),
  ]);
}

String sgBoardAsset(SgBoardKind kind) => switch (kind) {
      SgBoardKind.desk => 'assets/smartgen/desk.jpg',
      SgBoardKind.table => 'assets/smartgen/table.jpg',
      SgBoardKind.longTable => 'assets/smartgen/long_table.jpg',
      SgBoardKind.coffeeTable => 'assets/smartgen/coffee.jpg',
      SgBoardKind.longBench || SgBoardKind.nightStand => 'assets/smartgen/bench.jpg',
      SgBoardKind.roundTable => 'assets/smartgen/round.jpg',
      SgBoardKind.workbench => 'assets/smartgen/metal.jpg',
      _ => 'assets/smartgen/stucco.jpg',
    };

/// Where cards sit inside the object, inside the object's own box.
EdgeInsets sgObjectInsets(String kind) => switch (kind) {
      'Notebook' || 'Diary' || 'Journal' => const EdgeInsets.fromLTRB(18, 28, 10, 14),
      'Gallery' || 'Portfolio' || 'Collection' => const EdgeInsets.fromLTRB(14, 26, 12, 12),
      'Folder' => const EdgeInsets.fromLTRB(8, 28, 8, 8),
      'Glass' => const EdgeInsets.fromLTRB(10, 22, 10, 10),
      'Name Photo Description' => const EdgeInsets.fromLTRB(8, 78, 8, 6),
      'Chart' || 'Calendar Widget' => const EdgeInsets.fromLTRB(8, 36, 8, 4),
      'Mirror' => const EdgeInsets.fromLTRB(14, 26, 14, 14),
      _ => const EdgeInsets.fromLTRB(8, 22, 8, 8),
    };

Widget sgObjectFace(String kind) {
  return SizedBox.expand(child: switch (kind) {
    'Notebook' || 'Diary' || 'Journal' => _openBook(kind),
    'Gallery' => _album(),
    'Portfolio' || 'Collection' => _leatherFolio(kind),
    'Folder' => _folder(),
    'Glass' => const SizedBox.expand(),
    'Mirror' => _mirror(),
    'Table' => _tableTop(),
    'Swimlane vertical' || 'Swimlane horizontal' || 'Kanban Board widget' => _plasterBoard(),
    'Calendar Widget' => _paperSheet(child: Padding(padding: const EdgeInsets.only(top: 20), child: _monthGrid())),
    'Chart' => _paperSheet(child: const CustomPaint(painter: _ChartBarsPainter(), child: SizedBox.expand())),
    'Name Photo Description' => _namePhoto(),
    _ => _paperSheet(),
  });
}

Widget _photo(String asset, {BoxFit fit = BoxFit.cover}) => Image.asset(asset, fit: fit, filterQuality: FilterQuality.medium);

Widget _openBook(String kind) {
  return Stack(fit: StackFit.expand, children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 5))],
          image: const DecorationImage(image: AssetImage('assets/smartgen/leather.jpg'), fit: BoxFit.cover),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 6, 8),
      child: Row(children: [
        Expanded(child: _page()),
        const SizedBox(width: 5),
        Expanded(child: _page(ruled: kind == 'Notebook')),
      ]),
    ),
  ]);
}

Widget _page({bool ruled = false}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: Stack(fit: StackFit.expand, children: [
      _photo('assets/smartgen/paper.jpg'),
      if (ruled) const CustomPaint(painter: _RulePainter()),
    ]),
  );
}

Widget _album() {
  return Stack(fit: StackFit.expand, children: [
    DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 5))],
        image: const DecorationImage(image: AssetImage('assets/smartgen/leather.jpg'), fit: BoxFit.cover),
      ),
    ),
    Padding(
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        Expanded(child: _mat()),
        const SizedBox(width: 8),
        Expanded(child: _mat()),
      ]),
    ),
  ]);
}

Widget _mat() {
  return DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xFFF4EFE4),
      boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1C1B19), width: 3),
            image: const DecorationImage(image: AssetImage('assets/smartgen/linen.jpg'), fit: BoxFit.cover),
          ),
        ),
      ),
    ),
  );
}

Widget _leatherFolio(String kind) {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 5))],
      image: DecorationImage(
        image: AssetImage(kind == 'Collection' ? 'assets/smartgen/linen.jpg' : 'assets/smartgen/leather.jpg'),
        fit: BoxFit.cover,
      ),
    ),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 10, 10),
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            image: const DecorationImage(image: AssetImage('assets/smartgen/paper.jpg'), fit: BoxFit.cover),
          ),
        ),
      ),
    ),
  );
}

Widget _folder() {
  return Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 78,
          height: 16,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            image: DecorationImage(image: AssetImage('assets/smartgen/cardboard.jpg'), fit: BoxFit.cover),
          ),
          child: const Text('Folder', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1C1B19))),
        ),
      ),
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 4))],
            image: const DecorationImage(image: AssetImage('assets/smartgen/cardboard.jpg'), fit: BoxFit.cover),
          ),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(image: AssetImage('assets/smartgen/paper.jpg'), fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ),
    ]),
  );
}

Widget _mirror() {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xFF1A120C), width: 8),
      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 5))],
      image: const DecorationImage(image: AssetImage('assets/smartgen/desk.jpg'), fit: BoxFit.cover),
    ),
  );
}

Widget _tableTop() {
  return Padding(
    padding: const EdgeInsets.all(8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF3A2414), width: 6),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 4))],
        image: const DecorationImage(image: AssetImage('assets/smartgen/table.jpg'), fit: BoxFit.cover),
      ),
    ),
  );
}

Widget _plasterBoard() {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0xFF8A8A86), width: 4),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 4))],
      image: const DecorationImage(image: AssetImage('assets/smartgen/stucco.jpg'), fit: BoxFit.cover),
    ),
  );
}

Widget _namePhoto() {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 4))],
      image: const DecorationImage(image: AssetImage('assets/smartgen/paper.jpg'), fit: BoxFit.cover),
    ),
    child: const Padding(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: Color(0xFF1C1B19), width: 3)),
              image: DecorationImage(image: AssetImage('assets/smartgen/linen.jpg'), fit: BoxFit.cover),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text('Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1C1B19))),
        Text('Description', style: TextStyle(fontSize: 9, color: Color(0xFF5C564C))),
      ]),
    ),
  );
}

Widget _paperSheet({Widget? child}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 4))],
      image: const DecorationImage(image: AssetImage('assets/smartgen/paper.jpg'), fit: BoxFit.cover),
    ),
    child: child,
  );
}

Widget _monthGrid() {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month + 1, 0).day;
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Wrap(spacing: 2, runSpacing: 2, children: [
      for (var d = 1; d <= days; d++)
        SizedBox(width: 18, child: Text('$d', style: const TextStyle(fontSize: 9, color: Color(0xFF1C1B19)))),
    ]),
  );
}

Widget _bars(SgBoard board) {
  final counts = <String, int>{};
  for (final c in board.cards) {
    counts[c.type.label] = (counts[c.type.label] ?? 0) + 1;
  }
  if (counts.isEmpty) {
    return const CustomPaint(painter: _ChartBarsPainter(), child: SizedBox.expand());
  }
  final maxN = counts.values.fold<int>(1, (m, n) => n > m ? n : m);
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (final e in counts.entries.take(6))
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              SizedBox(height: 28.0 * e.value / maxN, child: const ColoredBox(color: Color(0xFF3D7A6A))),
              Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: Color(0xFF1C1B19))),
            ]),
          ),
        ),
    ]),
  );
}

class _ChartBarsPainter extends CustomPainter {
  const _ChartBarsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF3D7A6A);
    const heights = [0.35, 0.8, 0.25, 0.62, 0.48];
    final gap = size.width * 0.04;
    final barW = (size.width - gap * (heights.length + 1)) / heights.length;
    for (var i = 0; i < heights.length; i++) {
      final h = size.height * heights[i];
      final x = gap + i * (barW + gap);
      canvas.drawRect(Rect.fromLTWH(x, size.height - h - 8, barW, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RulePainter extends CustomPainter {
  const _RulePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x554A6FA5)
      ..strokeWidth = 1;
    final margin = Paint()
      ..color = const Color(0x66B04040)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(14, 0), Offset(14, size.height), margin);
    for (var y = 16.0; y < size.height; y += 13) {
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
