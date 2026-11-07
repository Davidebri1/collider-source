import 'sg_model.dart';

/// Photographic surfaces for Smart Gen boards and canvases.
/// Sources, licences, and modifications are recorded in ASSETS.md.
/// These are CC0 photographs. The app wallpaper is never used as a desk.

String sgBoardPhoto(SgBoardKind kind) => switch (kind) {
      SgBoardKind.desk => 'assets/smartgen/desk.jpg',
      SgBoardKind.table => 'assets/smartgen/table.jpg',
      SgBoardKind.longTable => 'assets/smartgen/long_table.jpg',
      SgBoardKind.coffeeTable => 'assets/smartgen/coffee.jpg',
      SgBoardKind.longBench => 'assets/smartgen/bench.jpg',
      SgBoardKind.roundTable => 'assets/smartgen/round.jpg',
      SgBoardKind.nightStand => 'assets/smartgen/bench.jpg',
      SgBoardKind.workbench => 'assets/smartgen/metal.jpg',
      SgBoardKind.kanban ||
      SgBoardKind.calendar ||
      SgBoardKind.whiteboard ||
      SgBoardKind.whiteboardLanes ||
      SgBoardKind.whiteboardPlain ||
      SgBoardKind.charts =>
        'assets/smartgen/stucco.jpg',
    };

/// Working-surface photograph for a canvas type name.
String sgCanvasPhoto(String kind) => switch (kind) {
      'Folder' => 'assets/smartgen/cardboard.jpg',
      'Portfolio' || 'Collection' => 'assets/smartgen/leather.jpg',
      'Gallery' => 'assets/smartgen/linen.jpg',
      'Table' => 'assets/smartgen/table.jpg',
      'Mirror' => 'assets/smartgen/desk.jpg',
      'Kanban Board widget' || 'Swimlane vertical' || 'Swimlane horizontal' => 'assets/smartgen/stucco.jpg',
      _ => 'assets/smartgen/paper.jpg',
    };

/// Spec canvas types, in summary.txt order. The name is the default object name.
const List<String> kSgCanvasTypeNames = [
  'Glass',
  'Mirror',
  'Swimlane vertical',
  'Swimlane horizontal',
  'Name Photo Description',
  'Portfolio',
  'Notebook',
  'Collection',
  'Folder',
  'Gallery',
  'Diary',
  'Journal',
  'Kanban Board widget',
  'Table',
  'Calendar Widget',
  'Chart',
];
