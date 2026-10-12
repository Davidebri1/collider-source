// Collider API client. Made by Claude.
// Talks only to the local Collider server (tools/collider_server.py), which holds the keys.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../models/model_def.dart';

enum AskMode { chat, internet, research, deep }

extension AskModeX on AskMode {
  String get wire => switch (this) {
        AskMode.chat => 'chat',
        AskMode.internet => 'internet',
        AskMode.research => 'research',
        AskMode.deep => 'deep',
      };
}

class ModelResult {
  final String status; // pending | done | error
  final String text;
  final String essence;
  final String? error;
  const ModelResult(this.status, this.text, this.essence, this.error);
  factory ModelResult.fromJson(Map<String, dynamic> j) => ModelResult(
        j['status'] as String? ?? 'pending',
        j['text'] as String? ?? '',
        j['essence'] as String? ?? '',
        j['error'] as String?,
      );
}

/// One response's logical chain measurement. [chains] is the total chain depth
/// and [max] the longest single chain, per the Consensus Agent spec.
class ChainEntry {
  final String model;
  final int chains;
  final int max;
  const ChainEntry(this.model, this.chains, this.max);
  factory ChainEntry.fromJson(Map<String, dynamic> j) => ChainEntry(
        '${j['model']}',
        ((j['chains'] as num?) ?? 0).toInt(),
        ((j['max'] as num?) ?? 0).toInt(),
      );
}

/// A sentiment group and the models that share it.
class SentimentGroup {
  final String sentiment;
  final List<String> models;
  const SentimentGroup(this.sentiment, this.models);
  factory SentimentGroup.fromJson(Map<String, dynamic> j) => SentimentGroup(
        j['sentiment'] as String? ?? '',
        ((j['models'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}

/// The three fields the Consensus Agent spec actually defines. There is no
/// dissent and no need: the spec records reality, it does not advise.
///
/// [score] is a count rendered as n/total. Per PRD R17 an unfinished send
/// shows an empty score rather than a placeholder or a percent.
class ConsensusResult {
  final String status; // pending | done | unavailable | empty
  final String ratio; // "4/7"
  final String score; // "4/7" or "" while incomplete
  final String summary; // verbatim from a member response
  final List<SentimentGroup> groups;
  final List<ChainEntry> chains;
  final String consensusChain; // e.g. "5 chains, max 4"
  final List<String> excluded; // R41: out of the shared query, shown not hidden

  const ConsensusResult(
    this.status,
    this.ratio,
    this.score,
    this.summary, {
    this.groups = const [],
    this.chains = const [],
    this.consensusChain = '',
    this.excluded = const [],
  });

  /// R16/R17: an incomplete shared send shows an empty score, never a
  /// "waiting" line and never a percent.
  bool get complete => score.isNotEmpty && status == 'done';

  factory ConsensusResult.fromJson(Map<String, dynamic>? j) => ConsensusResult(
        j?['status'] as String? ?? 'pending',
        j?['ratio'] as String? ?? '',
        j?['score'] as String? ?? '',
        j?['summary'] as String? ?? '',
        groups: [for (final g in (j?['groups'] as List?) ?? const []) SentimentGroup.fromJson(Map<String, dynamic>.from(g as Map))],
        chains: [for (final c in (j?['chains'] as List?) ?? const []) ChainEntry.fromJson(Map<String, dynamic>.from(c as Map))],
        consensusChain: j?['consensus_chain'] as String? ?? '',
        excluded: ((j?['excluded'] as List?) ?? const []).map((e) => '$e').toList(),
      );

  /// Chain depth for one model, or 0 when it was not measured.
  int chainsFor(String model) {
    for (final c in chains) {
      if (c.model == model) return c.chains;
    }
    return 0;
  }

  int maxChainFor(String model) {
    for (final c in chains) {
      if (c.model == model) return c.max;
    }
    return 0;
  }
}

class JobState {
  final String id;
  final String prompt;
  final String mode;
  final String stage;
  final bool done;
  final Map<String, ModelResult> results;
  final ConsensusResult consensus;
  final List<Map<String, dynamic>> sources;
  final DateTime created;
  const JobState(this.id, this.prompt, this.mode, this.stage, this.done, this.results, this.consensus, this.sources, this.created);
  factory JobState.fromJson(Map<String, dynamic> j) => JobState(
        j['id'] as String,
        j['prompt'] as String? ?? '',
        j['mode'] as String? ?? 'chat',
        j['stage'] as String? ?? '',
        (j['status'] ?? 'done') == 'done',
        ((j['results'] as Map?) ?? {}).map((k, v) => MapEntry('$k', ModelResult.fromJson(Map<String, dynamic>.from(v as Map)))),
        ConsensusResult.fromJson(j['consensus'] == null ? null : Map<String, dynamic>.from(j['consensus'] as Map)),
        ((j['sources'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        DateTime.fromMillisecondsSinceEpoch((((j['created'] as num?) ?? 0) * 1000).toInt()),
      );
}

class ColliderApi {
  ColliderApi._();
  static final ColliderApi instance = ColliderApi._();
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 180)));

  String get _base => Uri.base.origin;
  bool online = false;
  bool webSearch = false;
  int nvidiaKeys = 0;

  static Color _hex(String h) => Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));

  /// Loads the live roster from the server into [ModelRoster]. Returns true when connected.
  Future<bool> loadRoster() async {
    try {
      final r = await _dio.get('$_base/api/models');
      final list = (r.data['models'] as List).cast<Map>();
      webSearch = r.data['search'] == true;
      nvidiaKeys = (r.data['keys'] as num?)?.toInt() ?? 0;
      ModelRoster.setLive([
        for (final m in list)
          ModelDef(
            id: m['id'] as String,
            label: m['label'] as String,
            provider: m['provider'] as String,
            tier: ModelTier.free,
            categories: const [ModelCategory.general],
            providerColor: _hex(m['color'] as String),
          ),
      ]);
      online = true;
    } catch (_) {
      online = false;
    }
    return online;
  }

  /// [excluded] is the R41 isolation set: models a direct reply took out of the
  /// shared query. They still answer, they are just not counted, and the server
  /// reports them back as excluded rather than dropping them. A general send
  /// passes an empty list and every selected model is counted again.
  Future<String> ask({
    required String prompt,
    required List<String> models,
    required AskMode mode,
    required bool autosave,
    required bool incognito,
    List<String> excluded = const [],
  }) async {
    final r = await _dio.post('$_base/api/ask', data: {
      'prompt': prompt,
      'models': models,
      'mode': mode.wire,
      'autosave': autosave,
      'incognito': incognito,
      'excluded': excluded,
    });
    return r.data['id'] as String;
  }

  /// Polls a job until done, emitting each state.
  Stream<JobState> watch(String id) async* {
    while (true) {
      final r = await _dio.get('$_base/api/job/$id');
      final s = JobState.fromJson(Map<String, dynamic>.from(r.data as Map));
      yield s;
      if (s.done) return;
      await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  Future<({String text, String essence})> reply({required String model, required List<Map<String, String>> messages, required AskMode mode}) async {
    final r = await _dio.post('$_base/api/reply', data: {'model': model, 'messages': messages, 'mode': mode.wire});
    return (text: r.data['text'] as String, essence: r.data['essence'] as String);
  }

  Future<List<JobState>> history() async {
    try {
      final r = await _dio.get('$_base/api/history');
      return [
        for (final s in (r.data['sessions'] as List)) JobState.fromJson({...Map<String, dynamic>.from(s as Map), 'status': 'done'}),
      ];
    } catch (_) {
      return const [];
    }
  }
}
