import 'dart:convert';

import 'package:flutter/material.dart';

import '../sg_pane.dart';

/// Parses the Smart Gen agent's reply into the derived need, how the cards
/// serve it, and the proposed cards. Kept out of the widget so it can be
/// tested against the shapes a model actually returns.
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

/// Smart Gen, hosted in the one centred pane. The board, the lists and the
/// card fields follow the trello-clone model. The surfaces follow the
/// binding ledger: one card set, switched in place.
class SmartGenScreen extends StatelessWidget {
  const SmartGenScreen({super.key, required this.onClose, this.section = 'tasks'});
  final VoidCallback onClose;
  final String section;

  @override
  Widget build(BuildContext context) => SgPane(onClose: onClose, section: section);
}
