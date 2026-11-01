import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:planka_app/embed.dart';

import '../../../core/api/media_gen.dart';
import '../planka_migrate.dart';
import '../sg_model.dart';
import '../sg_pane.dart';
import '../../../core/account_sync/account_sync.dart';

({String need, String serve, List<(String title, String note)> cards}) parseSmartGen(String out) {
  final need = RegExp(r'NEED:\s*(.+)').firstMatch(out)?.group(1)?.trim() ?? '';
  final serve = RegExp(r'SERVE:\s*(.+)').firstMatch(out)?.group(1)?.trim() ?? '';
  final block = RegExp(r'CARDS:\s*([\s\S]+)').firstMatch(out)?.group(1) ?? '';
  final cards = <(String, String)>[];
  for (final line in const LineSplitter().convert(block)) {
    final t = line.trimLeft();
    if (!t.startsWith('-')) continue;
    final parts = t.substring(1).trim().split('|');
    final title = parts.first.trim();
    if (title.isEmpty) continue;
    cards.add((title, parts.length > 1 ? parts.sublist(1).join('|').trim() : ''));
    if (cards.length == 6) break;
  }
  return (need: need, serve: serve, cards: cards);
}

/// Surfaces that open in the planka_app board UI. Every other [SgSurface] keeps
/// the live SgPane screen (notebook, album, vision, …) with boards.json intact.
const kPlankaSurfaces = {'kanban'};

bool smartGenSectionIsLive(String section) {
  // Cards/Boards stay on stock planka; only explicit live surfaces use SgPane.
  if (section == 'tasks' || section == 'live' || section == 'genie') return true;
  if (section == 'planka' || section == 'boards' || section == 'cards' || section.isEmpty) return false;
  // Named surface e.g. album / notebook / vision / canvas → live screen.
  if (kPlankaSurfaces.contains(section)) return false;
  return SgSurface.values.asNameMap().containsKey(section);
}

/// Smart Gen — kanban boards in planka_app; all other kinds in live SgPane.
class SmartGenScreen extends StatefulWidget {
  const SmartGenScreen({super.key, required this.onClose, this.section = 'planka'});
  final VoidCallback onClose;
  final String section;

  @override
  State<SmartGenScreen> createState() => _SmartGenScreenState();
}

class _SmartGenScreenState extends State<SmartGenScreen> {
  Future<void>? _ready;
  static const _blobId = 'smartgen/planka.json';
  late bool _live;

  @override
  void initState() {
    super.initState();
    _live = smartGenSectionIsLive(widget.section);
  }

  @override
  void didUpdateWidget(covariant SmartGenScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      setState(() => _live = smartGenSectionIsLive(widget.section));
    }
  }

  @override
  Widget build(BuildContext context) {
    _ready ??= () async {
      await ensurePlankaReady(
        genie: (messages) => MediaGen.instance.genie(messages),
        save: (json) async {
          await AccountSync.instance.putBlob(_blobId, Uint8List.fromList(utf8.encode(json)));
        },
        load: () async {
          try {
            final raw = await AccountSync.instance.getBlob(_blobId).timeout(const Duration(seconds: 2));
            if (raw == null || raw.isEmpty) return null;
            return utf8.decode(raw);
          } catch (_) {
            return null;
          }
        },
        attachmentPut: (id, bytes) async {
          await AccountSync.instance.putBlob(id, bytes);
        },
        attachmentGet: (id) => AccountSync.instance.getBlob(id),
      );
      await migrateLegacySmartGenIntoPlanka();
      await SgStore.instance.init();
      seedPlankaCaptureIfRequested();
    }();

    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ColoredBox(color: Color(0xFFF4F5F7), child: SizedBox.expand());
        }
        if (snap.hasError) {
          return SgPane(onClose: widget.onClose, section: 'tasks');
        }
        if (_live) {
          final liveSection = switch (widget.section) {
            'planka' || 'boards' || 'cards' => 'tasks',
            'genie' => 'genie',
            'canvas' => 'canvas',
            _ => widget.section,
          };
          return SgPane(
            key: const ValueKey('sg-live-pane'),
            onClose: () {
              // From the planka hub, back returns to kanban UI; otherwise close Smart Gen.
              if (widget.section == 'planka' || widget.section == 'boards') {
                setState(() => _live = false);
              } else {
                widget.onClose();
              }
            },
            section: liveSection,
            onOpenKanbanInPlanka: () => setState(() => _live = false),
          );
        }
        return _PersistHost(
          child: PlankaNavigator(
            onClose: widget.onClose,
            onOpenLiveSurfaces: () => setState(() => _live = true),
          ),
        );
      },
    );
  }
}

class _PersistHost extends StatefulWidget {
  const _PersistHost({required this.child});
  final Widget child;
  @override
  State<_PersistHost> createState() => _PersistHostState();
}

class _PersistHostState extends State<_PersistHost> {
  @override
  void dispose() {
    persistPlanka();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
