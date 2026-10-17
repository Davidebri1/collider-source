// v9.1.7 pane guard (David, Oct 15 5:08 AM): make layout violations
// impossible to build. Run by tool/build_web.sh before every build and by
// test/pane_guard_test.dart.
//
// Rules, for every file under lib/features (screens never paint their own
// surface; lib/core/vision/cpane.dart is the one place that may):
//   blur      BackdropFilter / ImageFilter.blur
//   shadow    BoxShadow( / boxShadow:
//   glass     VGlass( (panes use CPane)
//   width     MediaQuery width used for layout, VOverlay.tool/menuWidth
// and for lib/main.dart (the shell):
//   rawpane   a pane mounted in a raw Positioned with its own left/right
//
// Files that still break a rule are listed in tool/pane_guard_baseline.json
// with their current count. A count can only go DOWN: any new file, or any
// higher count, fails. Moving a screen onto CPane removes its entry.
import 'dart:convert';
import 'dart:io';

final rules = <String, RegExp>{
  'blur': RegExp(r'BackdropFilter|ImageFilter\.blur'),
  'shadow': RegExp(r'BoxShadow\(|boxShadow:'),
  'glass': RegExp(r'\b(VGlass|FGlass|VWindow)\('),
  'width': RegExp(r'MediaQuery\.(sizeOf|of)\(\w+\)(\.size)?\.width|\.size\.width\b|VOverlay\.(tool|menu)Width'),
};
final shellRules = <String, RegExp>{
  'rawpane': RegExp(r'Positioned\(\s*\n?\s*left: isMobile \? 0 : 360'),
};

Map<String, Map<String, int>> scan(String root) {
  final out = <String, Map<String, int>>{};
  void count(String path, String text, Map<String, RegExp> rs) {
    // Comments do not count.
    final code = text.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');
    for (final e in rs.entries) {
      final n = e.value.allMatches(code).length;
      if (n > 0) (out[path] ??= {})[e.key] = n;
    }
  }
  final dir = Directory('$root/lib/features');
  for (final f in dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
    count(f.path.substring(root.length + 1), f.readAsStringSync(), rules);
  }
  final main = File('$root/lib/main.dart');
  if (main.existsSync()) count('lib/main.dart', main.readAsStringSync(), shellRules);
  return out;
}

int main(List<String> args) {
  final root = Directory.current.path;
  final now = scan(root);
  final baseFile = File('$root/tool/pane_guard_baseline.json');
  if (args.contains('--write-baseline')) {
    final sorted = Map.fromEntries(now.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    baseFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(sorted) + '\n');
    stdout.writeln('pane_guard: baseline written (${now.length} files)');
    return 0;
  }
  final base = baseFile.existsSync()
      ? (jsonDecode(baseFile.readAsStringSync()) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as Map<String, dynamic>).map((r, n) => MapEntry(r, n as int))))
      : <String, Map<String, int>>{};
  final errors = <String>[];
  var remaining = 0;
  for (final e in now.entries) {
    for (final r in e.value.entries) {
      final allowed = base[e.key]?[r.key] ?? 0;
      remaining += r.value;
      if (r.value > allowed) errors.add('${e.key}: ${r.key} x${r.value} (allowed $allowed). Use CPane / CLayer instead.');
    }
  }
  if (errors.isNotEmpty) {
    stderr.writeln('pane_guard FAILED:');
    for (final e in errors) stderr.writeln('  $e');
    return 1;
  }
  stdout.writeln('pane_guard ok: ${now.length} files still on the baseline, $remaining uses left to move onto CPane');
  return 0;
}
