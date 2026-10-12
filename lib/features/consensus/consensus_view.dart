// Consensus derivation for the map surface.
//
// Authority: docs/Consensus Agent.md (Consensus Agent) and
// docs/PRD-XLSX-EXTRACT.txt rows R16, R17 and R41.
//
// The recorder (server/collider-server.mjs) already resolved the consensus
// democratically and measured each response's logical chain depth. This file
// renders what it returned. It does not re-decide, re-score, or invent a
// position, a tie-break, a need, or a dissent.
//
// What this file deliberately no longer does:
//   - no `matches` map driving radius or cluster order. Match counting was a
//     v3-framework construct; the agent spec has no such field.
//   - no tie-break basis. The spec resolves democratically by member count and
//     stops there. A tie is a tie, and it is reported as one.
//   - no `need`. The spec records reality, it does not advise.
import 'dart:math' as math;

/// Sphere mass from chain depth. Chain depth is the only measured input, so it
/// is the only thing that may drive size.
int sphereSize(int chains) => (30 + math.max(0, chains) * 10).round();

class ConsensusClaim {
  final String modelId;
  final String essence;
  final int chains;
  final int maxChain;
  const ConsensusClaim({
    required this.modelId,
    required this.essence,
    required this.chains,
    this.maxChain = 0,
  });
}

class ConsensusResult {
  final List<ConsensusClaim> claims;
  /// Sentiment groups exactly as the recorder grouped them. The largest group
  /// is the consensus; the recorder already ordered them by size.
  final List<List<String>> groups;

  /// The recorder's own ratio string, e.g. "4/7". Empty while incomplete.
  final String ratio;

  /// The verbatim consensus summary. Copied from a member, never composed here.
  final String summary;

  /// R41: models a direct reply took out of the shared query. They are drawn
  /// as excluded, never silently omitted.
  final List<String> excluded;

  final bool degraded;
  const ConsensusResult({
    required this.claims,
    this.groups = const [],
    this.ratio = '',
    this.summary = '',
    this.excluded = const [],
    this.degraded = false,
  });
}

class DerivedClaim {
  final ConsensusClaim claim;
  final bool inConsensus;
  final bool excluded;
  final int size;
  const DerivedClaim(this.claim, this.inConsensus, this.size, {this.excluded = false});
  String get modelId => claim.modelId;
  int get chains => claim.chains;
  int get maxChain => claim.maxChain;
  String get essence => claim.essence;
}

class Derived {
  final List<DerivedClaim> claims;
  final List<String> consensus;

  /// Verbatim from a member response.
  final String summary;

  /// Consensus group members, for the chain row the spec asks for.
  final int consensusChains;
  final int consensusMaxChain;

  final String ratio;
  final int ratioN;
  final int ratioM;

  /// R16: a finished shared send shows a count. An unfinished one shows an
  /// empty score, never a percent and never a waiting line.
  final String score;
  final bool complete;

  final List<DerivedClaim> excluded;
  final bool degraded;

  const Derived({
    required this.claims,
    required this.consensus,
    required this.summary,
    required this.consensusChains,
    required this.consensusMaxChain,
    required this.ratio,
    required this.ratioN,
    required this.ratioM,
    required this.score,
    required this.complete,
    required this.excluded,
    required this.degraded,
  });

  /// Agreement as a 0..1 fraction, used only for glow weight. Never displayed.
  double get agreement => ratioM > 0 ? ratioN / ratioM : 0.0;
}

int _countOf(String ratio) => int.tryParse(ratio.split('/').first.trim()) ?? 0;

/// The consensus is the largest sentiment group. Groups arrive from the
/// recorder already ordered by member count; a tie is reported as a tie rather
/// than broken by a rule the spec does not contain.
Derived? deriveConsensus(ConsensusResult? result) {
  if (result == null || result.claims.isEmpty) return null;
  final byId = {for (final c in result.claims) c.modelId: c};
  final excludedSet = result.excluded.toSet();

  // Claims still on the shared query are the ones that count (R41).
  final counted = result.claims.where((c) => !excludedSet.contains(c.modelId)).toList();

  final groups = result.groups
      .map((g) => g.where(byId.containsKey).where((id) => !excludedSet.contains(id)).toList())
      .where((g) => g.isNotEmpty)
      .toList();
  // Any counted claim the recorder did not place is its own group of one.
  final placed = groups.expand((g) => g).toSet();
  for (final c in counted) {
    if (!placed.contains(c.modelId)) groups.add([c.modelId]);
  }

  // Largest group wins. Groups are assumed recorder-ordered; enforce it anyway
  // so a hand-edited payload cannot flip the consensus.
  groups.sort((a, b) => b.length.compareTo(a.length));
  final winner = groups.isEmpty ? <String>[] : groups.first;
  final inWinner = winner.toSet();

  final claims = result.claims
      .map((c) => DerivedClaim(
            c,
            inWinner.contains(c.modelId),
            sphereSize(c.chains),
            excluded: excludedSet.contains(c.modelId),
          ))
      .toList();

  final members = claims.where((c) => c.inConsensus).toList();
  final excludedClaims = claims.where((c) => c.excluded).toList();

  // Chain row for the consensus summary: the max across its members.
  final consensusChains = members.fold<int>(0, (m, c) => math.max(m, c.chains));
  final consensusMaxChain = members.fold<int>(0, (m, c) => math.max(m, c.maxChain));

  // Prefer the recorder's own ratio. Fall back to the group arithmetic only
  // when the recorder did not send one, and only as a count, never a percent.
  var ratioN = _countOf(result.ratio);
  var ratioM = 0;
  if (result.ratio.contains('/')) {
    final parts = result.ratio.split('/');
    if (parts.length == 2) ratioM = int.tryParse(parts[1].trim()) ?? 0;
  }
  if (ratioM == 0) {
    ratioM = counted.length;
    ratioN = winner.length;
  }
  final complete = result.ratio.isNotEmpty && ratioM > 0 && ratioN > 0;
  final score = complete ? '$ratioN/$ratioM' : '';

  return Derived(
    claims: claims,
    consensus: winner,
    summary: result.summary,
    consensusChains: consensusChains,
    consensusMaxChain: consensusMaxChain,
    ratio: result.ratio,
    ratioN: ratioN,
    ratioM: ratioM,
    score: score,
    complete: complete,
    excluded: excludedClaims,
    degraded: result.degraded,
  );
}

class Placed {
  final String modelId;
  final double x;
  final double y;
  final bool unanchored;
  final bool inConsensus;
  final bool excluded;
  const Placed({
    required this.modelId,
    required this.x,
    required this.y,
    required this.unanchored,
    required this.inConsensus,
    this.excluded = false,
  });
}

class Field {
  final double width, height, centerX, centerY, innerR, outerR;
  const Field({
    required this.width,
    required this.height,
    required this.centerX,
    required this.centerY,
    required this.innerR,
    required this.outerR,
  });
}

/// Consensus members sit on the inner ring in their group's order. Everything
/// else — dissent and excluded alike — sits outside it, ordered by group and
/// then by name so the layout is stable between frames.
List<Placed> layoutByGroup(Derived d, Field field) {
  final centerX = field.centerX, centerY = field.centerY;
  final innerR = field.innerR, outerR = field.outerR;

  final placed = <Placed>[];
  for (var i = 0; i < d.consensus.length; i++) {
    final id = d.consensus[i];
    final a = (-math.pi / 2) + (i * 2 * math.pi) / math.max(d.consensus.length, 1);
    final chains = d.claims.where((c) => c.modelId == id).firstOrNull?.chains ?? 0;
    placed.add(Placed(
      modelId: id,
      x: centerX + math.cos(a) * innerR,
      y: centerY + math.sin(a) * innerR * 0.72,
      unanchored: chains == 0,
      inConsensus: true,
    ));
  }

  final outsiders = d.claims.where((c) => !c.inConsensus).toList()
    ..sort((a, b) => a.modelId.compareTo(b.modelId));
  final sectors = math.max(outsiders.length, 1);
  for (var k = 0; k < outsiders.length; k++) {
    final c = outsiders[k];
    final a = math.pi / 2 + (k * 2 * math.pi) / sectors;
    placed.add(Placed(
      modelId: c.modelId,
      x: centerX + math.cos(a) * outerR,
      y: centerY + math.sin(a) * outerR * 0.72,
      unanchored: c.chains == 0,
      inConsensus: false,
      excluded: c.excluded,
    ));
  }
  return placed;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
