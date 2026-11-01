import 'package:flutter/material.dart';

import '../../hooks.dart';
import 'genie_actions.dart';

class GenieScreen extends StatefulWidget {
  const GenieScreen({super.key});
  @override
  State<GenieScreen> createState() => _GenieScreenState();
}

class _GenieScreenState extends State<GenieScreen> {
  final _ctrl = TextEditingController();
  final _messages = <Map<String, String>>[];
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _messages.add({'role': 'user', 'content': text});
      _ctrl.clear();
    });
    final chat = plankaGenieChat;
    try {
      if (text.toLowerCase() == 'new conversation') {
        _messages
          ..clear()
          ..add({'role': 'assistant', 'content': 'Started a new conversation.'});
      } else if (chat == null) {
        // No host Genie wire — stay silent (no invented copy).
      } else {
        final ctx = plankaBoardContextForGenie();
        final llmMessages = <Map<String, String>>[
          {'role': 'system', 'content': kPlankaGenieSystemPrompt},
          {
            'role': 'user',
            'content': 'Board JSON:\n$ctx\n\nUser request:\n$text\nRespond with the JSON object only.',
          },
        ];
        var raw = await chat(llmMessages);
        if (extractGenieJson(raw) == null) {
          raw = await chat([
            ...llmMessages,
            {'role': 'assistant', 'content': raw},
            {
              'role': 'user',
              'content':
                  'That was not valid JSON. Reply again with ONLY the JSON object {"reply":"...","actions":[...]} and no other text.',
            },
          ]);
        }
        final reply = applyPlankaGenieReply(raw);
        _messages.add({'role': 'assistant', 'content': reply});
      }
    } catch (e) {
      _messages.add({'role': 'assistant', 'content': '$e'});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Icon(Icons.auto_awesome),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final mine = m['role'] == 'user';
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: mine ? Colors.indigo.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(m['content'] ?? ''),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
                IconButton(onPressed: _busy ? null : _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
