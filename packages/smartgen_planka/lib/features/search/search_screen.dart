import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _hits = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _run(String q) {
    setState(() => _hits = PlankaStore.instance.search(q));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Data input field — left align (theme centres titles by default).
        centerTitle: false,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _run,
          decoration: const InputDecoration(
            border: InputBorder.none,
            // icon-only hint
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: _hits.length,
        itemBuilder: (_, i) {
          final h = _hits[i];
          return ListTile(
            leading: Icon(h['kind'] == 'board'
                ? Icons.dashboard_outlined
                : h['kind'] == 'field'
                    ? Icons.tune
                    : Icons.style_outlined),
            title: Text('${h['name'] ?? ''}'),
            subtitle: h['fieldValue'] != null ? Text('${h['fieldValue']}') : null,
          );
        },
      ),
    );
  }
}
