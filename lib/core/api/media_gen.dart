import 'dart:async';
// v8.3 media restore: a Dart port of the source app's provider client
// (collidermergedx3-glm/src/services/chat.ts ROUTES + callOpenRouterImage /
// callOpenRouterVideo / callOpenRouterSpeech / callOpenRouterAudio /
// generateImageUrl, and wire.ts wireFor). Same endpoints, same request
// bodies, same polling.
//
// Keys: the source ships its provider keys inline in the bundle. This build
// does NOT (DEVIATIONS D58): a public GitHub Pages bundle would hand them to
// anyone. They are read from --dart-define at build time and are empty in
// the hosted build, so a run fails quietly at send time (D59).
// Exact define names: OPENROUTER_KEY, CRAZYROUTER_KEY, NVIDIA_KEY,
// COMMANDCODE_KEY, OPENCODE_KEY, MINIMAX_KEY, COLLIDER_PROXY.
// Box/CI: set COLLIDER_OPENROUTER_KEY (etc.) and run tool/build_web.sh —
// see docs/DART_DEFINES.md. Never log key values.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/media_specs.dart';

const String _openRouterKey = String.fromEnvironment('OPENROUTER_KEY');
const String _crazyRouterKey = String.fromEnvironment('CRAZYROUTER_KEY');
const String _openRouterBase = 'https://openrouter.ai/api/v1';
// v8.5 text wires (David's keys, given at build time with --dart-define).
const String _nvidiaKey = String.fromEnvironment('NVIDIA_KEY');
const String _commandCodeKey = String.fromEnvironment('COMMANDCODE_KEY');
const String _openCodeKey = String.fromEnvironment('OPENCODE_KEY');
const String _minimaxKey = String.fromEnvironment('MINIMAX_KEY');
/// Server that forwards to providers that refuse browser calls (NVIDIA, OpenCode).
const String _proxy = String.fromEnvironment('COLLIDER_PROXY');
const Map<String, ({String base, String key, bool cors})> _textWires = {
  'nv': (base: 'https://integrate.api.nvidia.com/v1', key: _nvidiaKey, cors: false),
  'cc': (base: 'https://api.commandcode.ai/provider/v1', key: _commandCodeKey, cors: true),
  'oc': (base: 'https://opencode.ai/zen/v1', key: _openCodeKey, cors: false),
  'mm': (base: 'https://api.minimax.io/v1', key: _minimaxKey, cors: true),
  'cr': (base: 'https://crazyrouter.com/v1', key: _crazyRouterKey, cors: true),
};
const Map<String, String> _proxyRoute = {'nv': 'nvidia', 'oc': 'opencode'};

/// CrazyRouter serves the same models under bare slugs rather than namespaced
/// ones, so a remote id is rewritten before it goes out on that wire.
String _wireSlug(String wire, String remote) =>
    wire == 'cr' ? (_slugOverrides[remote] ?? remote) : remote;

/// Each text model's ordered list of (wire, remote id) attempts.
const Map<String, List<(String, String)>> _text = {
  'free/glm-5-3-flash': [('nv', 'z-ai/glm-5.3-flash'), ('nv', 'z-ai/glm-5.3-flash')],
  'free/laguna-s-2-1': [('cc', 'poolside/laguna-s-2.1-free')],
  'free/laguna-xs-2-1': [('nv', 'poolside/laguna-xs-2.1'), ('nv', 'poolside/laguna-xs-2.1')],
  'free/ling-3-1-flash': [('cc', 'inclusionai/ling-3.1-flash:free')],
  'free/nemotron-3-5-lightning': [('nv', 'nvidia/nemotron-3.5-lightning-30b-a3b')],
  'pro/glm-5-3': [('nv', 'z-ai/glm-5.3'), ('oc', 'glm-5.3'), ('cc', 'zai-org/GLM-5.3')],
  'pro/deepseek-4-1-flash': [('nv', 'deepseek-ai/deepseek-v4.1-flash'), ('oc', 'deepseek-v4.1-flash'), ('cc', 'deepseek/deepseek-v4.1-flash')],
  'pro/minimax-m3': [('mm', 'MiniMax-M3'), ('cc', 'MiniMaxAI/MiniMax-M3'), ('oc', 'minimax-m3')],
  'pro/mimo-v2-6-flash': [('cc', 'xiaomi/mimo-v2.6-flash')],
  'pro/nemotron-3-ultra': [('nv', 'nvidia/nemotron-3-ultra-550b-a55b'), ('cc', 'nvidia/nemotron-3-ultra-550b-a55b')],
  'elite/kimi-k3': [('nv', 'moonshotai/kimi-k3'), ('oc', 'kimi-k3'), ('cc', 'moonshotai/Kimi-K3')],
};

/// The judge for the Consensus Agent and the Smart Gen agent, strongest first.
/// Each entry expands to that model's full backup list before the next model
/// is tried, so the judge survives any one provider being down. The keyless
/// floor underneath them all lives in `consensus`.
const List<String> consensusModels = [
  'pro/minimax-m3',
  'elite/kimi-k3',
  'pro/deepseek-4-1-flash',
  'pro/glm-5-3',
  'free/glm-5-3-flash',
  'pro/nemotron-3-ultra',
  'free/nemotron-3-5-lightning',
];

/// chat.ts friendlyErrorMessage, restored: our own words, never provider text.
String friendlyErrorMessage(Object error) {
  final msg = '$error';
  if (msg.contains('no-key')) return "This model isn't connected in this build yet. Pick another model.";
  if (msg.contains('cors')) return "Couldn't reach this model from the browser. Try again or switch models.";
  if (RegExp(r'\b402\b|quota|insufficient|funds|balance|usage limit').hasMatch(msg)) return 'This model is temporarily unavailable. Try another.';
  if (RegExp(r'\b429\b').hasMatch(msg)) return 'This model is getting a lot of requests right now — try again in a moment.';
  if (RegExp(r'\b401\b|\b403\b').hasMatch(msg)) return "This model couldn't be reached with your current access — try again or switch models.";
  if (RegExp(r'timeout|network|fetch|unreachable', caseSensitive: false).hasMatch(msg)) return "Couldn't reach this model — check your connection and try again.";
  if (RegExp(r'\b5\d\d\b').hasMatch(msg)) return 'This model is temporarily unavailable. Try again shortly.';
  if (msg.contains('empty')) return 'This model returned an empty reply. Try again, or pick another.';
  return 'Something went wrong generating a response. Try again.';
}

String _stripThink(String t) => t.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').replaceAll(RegExp(r'^[\s\S]*</think>'), '').trim();
const String _crazyRouterBase = 'https://crazyrouter.com/v1';

class _Route {
  final String provider;
  final String remote;
  final bool crazy;
  final String? voice;
  const _Route(this.provider, this.remote, {this.crazy = false, this.voice});
}

/// chat.ts ROUTES: the media and OpenRouter-text rows, verbatim.
const Map<String, _Route> _routes = {
  // General / coding over OpenRouter (the text routes the source sends there).
  'free/mistral-small': _Route('openrouter', 'mistralai/mistral-small-3.2-24b-instruct'),
  'free/command-r': _Route('openrouter', 'cohere/command-r-08-2024'),
  'free/ling-2-6-flash': _Route('openrouter', 'inclusionai/ling-2.6-flash'),
  'free/mistral-nemo': _Route('openrouter', 'mistralai/mistral-nemo'),
  'free/gemma-4-31b': _Route('openrouter', 'google/gemma-4-31b-it'),
  'free/gpt-5-nano': _Route('openrouter', 'openai/gpt-5-nano', crazy: true),
  'free/laguna-s-2-1': _Route('openrouter', 'poolside/laguna-s-2.1'),
  'pro/mercury-2': _Route('openrouter', 'inception/mercury-2'),
  'pro/mimo-v2-5-pro': _Route('openrouter', 'xiaomi/mimo-v2.5-pro'),
  'pro/gpt-5-6-luna': _Route('openrouter', 'openai/gpt-5.6-luna', crazy: true),
  'pro/qwen-3-6-plus': _Route('openrouter', 'qwen/qwen3.6-plus', crazy: true),
  'pro/grok-latest': _Route('openrouter', 'x-ai/grok-4.3', crazy: true),
  'pro/grok-4-5': _Route('openrouter', 'x-ai/grok-4.5'),
  'pro/sonar-reasoning-pro': _Route('openrouter', 'perplexity/sonar-reasoning-pro'),
  'pro/mistral-large': _Route('openrouter', 'mistralai/mistral-large'),
  'pro/laguna-s-2-1': _Route('openrouter', 'poolside/laguna-s-2.1'),
  'pro/kat-coder-air': _Route('openrouter', 'kwaipilot/kat-coder-air-v2.5'),
  'pro/codestral-2508': _Route('openrouter', 'mistralai/codestral-2508'),
  'pro/qwen-3-coder-plus': _Route('openrouter', 'qwen/qwen3-coder-plus', crazy: true),
  'pro/gpt-5-3-codex': _Route('openrouter', 'openai/gpt-5.3-codex', crazy: true),
  'pro/glm-5v-turbo': _Route('openrouter', 'z-ai/glm-5v-turbo', crazy: true),
  'elite/kat-coder-pro': _Route('openrouter', 'kwaipilot/kat-coder-pro-v2.5'),
  'elite/kimi-k2-7-code': _Route('openrouter', 'moonshotai/kimi-k2.7-code'),
  'elite/kimi-k3': _Route('openrouter', 'moonshotai/kimi-k3', crazy: true),
  'elite/qwen-3-7-max': _Route('openrouter', 'qwen/qwen3.7-max', crazy: true),
  // Keyless text (Pollinations OpenAI-compatible endpoint)
  'free/pollinations-openai': _Route('pollinations-text', 'openai'),
  // Image
  'img/flux-free': _Route('pollinations-image', ''),  // omit model= — free tier 402s named models
  'img/gemini-3-1-flash-image': _Route('openrouter-image', 'google/gemini-3.1-flash-image-preview'),
  'img/gpt-5-image-mini': _Route('openrouter-image', 'openai/gpt-5-image-mini'),
  'img/gemini-3-pro-image': _Route('openrouter-image', 'google/gemini-3-pro-image-preview'),
  'img/seedream-4-5': _Route('openrouter-image', 'bytedance-seed/seedream-4.5'),
  'img/nano-banana-2': _Route('openrouter-image', 'nano-banana-2', crazy: true),
  'img/nano-banana-pro': _Route('openrouter-image', 'nano-banana-pro', crazy: true),
  'img/seedream-5-0': _Route('openrouter-image', 'doubao-seedream-5-0', crazy: true),
  'img/qwen-image-2-0': _Route('openrouter-image', 'qwen-image-2.0', crazy: true),
  'img/gpt-image-2': _Route('openrouter-image', 'gpt-image-2', crazy: true),
  'img/dall-e-3': _Route('openrouter-image', 'dall-e-3', crazy: true),
  'img/kling-3-image': _Route('openrouter-image', 'aigc-image-kling-3.0', crazy: true),
  'img/mj-upscale': _Route('openrouter-image', 'mj_upscale', crazy: true),
  'img/flux-2-klein': _Route('openrouter-image', 'black-forest-labs/flux.2-klein-4b'),
  'img/flux-2-max': _Route('openrouter-image', 'black-forest-labs/flux.2-max'),
  'img/gpt-5-4-image-2': _Route('openrouter-image', 'openai/gpt-5.4-image-2'),
  // Video
  'vid/veo-3-1-lite': _Route('openrouter-video', 'google/veo-3.1-lite'),
  'vid/kling-3-standard': _Route('openrouter-video', 'kwaivgi/kling-v3.0-std'),
  'vid/grok-imagine-video': _Route('openrouter-video', 'x-ai/grok-imagine-video'),
  'vid/sora-2': _Route('openrouter-video', 'openai/sora-2-pro'),
  'vid/veo-3': _Route('openrouter-video', 'google/veo-3.1'),
  'vid/wan-2-6': _Route('openrouter-video', 'alibaba/wan-2.6'),
  'vid/veo-3-1-fast': _Route('openrouter-video', 'google/veo-3.1-fast'),
  'vid/hailuo-2-3': _Route('openrouter-video', 'minimax/hailuo-2.3'),
  'vid/wan-2-2-flash': _Route('openrouter-video', 'wan2.2-i2v-flash', crazy: true),
  'vid/wan-2-2-plus': _Route('openrouter-video', 'wan2.2-t2v-plus', crazy: true),
  'vid/wan-2-5-preview': _Route('openrouter-video', 'alibaba/wan-2.6', crazy: true),
  'vid/kling-2-5-turbo': _Route('openrouter-video', 'aigc-video-kling-2.5-turbo', crazy: true),
  'vid/kling-3-turbo': _Route('openrouter-video', 'aigc-video-kling-3.0-turbo', crazy: true),
  // Audio
  'aud/lyria-3-clip': _Route('openrouter-audio', 'google/lyria-3-clip-preview'),
  'aud/gpt-audio-mini': _Route('openrouter-audio', 'openai/gpt-audio-mini'),
  'aud/sesame-csm-1b': _Route('openrouter-speech', 'sesame/csm-1b', voice: 'conversational_a'),
  'aud/gpt-audio': _Route('openrouter-audio', 'openai/gpt-audio'),
  'aud/kokoro-82m': _Route('openrouter-speech', 'hexgrad/kokoro-82m', voice: 'af_bella'),
  'aud/gemini-3-1-flash-tts': _Route('openrouter-speech', 'google/gemini-3.1-flash-tts-preview', voice: 'Zephyr'),
  'aud/voxtral-mini-tts': _Route('openrouter-speech', 'mistralai/voxtral-mini-tts-2603'),
  'aud/lyria-3-pro': _Route('openrouter-audio', 'google/lyria-3-pro-preview'),
};

/// wire.ts SLUG_OVERRIDES (text rows) for when a Crazyrouter key is set.
const Map<String, String> _slugOverrides = {
  'openai/gpt-5-nano': 'gpt-5-nano',
  'openai/gpt-5.6-luna': 'gpt-5.6-luna',
  'openai/gpt-5.3-codex': 'gpt-5.3-codex',
  'z-ai/glm-5.2': 'glm-5.2',
  'z-ai/glm-5v-turbo': 'glm-5v-turbo',
  'qwen/qwen3.6-plus': 'qwen3.6-plus',
  'qwen/qwen3-coder-plus': 'qwen3-coder-plus',
  'qwen/qwen3.7-max': 'qwen3.7-max',
  'x-ai/grok-4.3': 'grok-4.3',
};

/// One generated asset. [url] is a data: URI or a plain URL.
class MediaResult {
  final String kind; // image | video | audio | text
  final String url;
  final String text;
  const MediaResult(this.kind, {this.url = '', this.text = ''});
}

class MediaGenError implements Exception {
  final String reason;
  const MediaGenError(this.reason);
  @override
  String toString() => reason;
}

class MediaGen {
  MediaGen._();
  static final MediaGen instance = MediaGen._();
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(minutes: 6)));

  ({String base, String key}) _wire(_Route r) {
    if (r.crazy && _crazyRouterKey.isNotEmpty) return (base: _crazyRouterBase, key: _crazyRouterKey);
    return (base: _openRouterBase, key: _openRouterKey);
  }

  String _slug(_Route r) => r.crazy && _crazyRouterKey.isNotEmpty ? (_slugOverrides[r.remote] ?? r.remote) : r.remote;

  bool isRoutable(String modelId) => _routes.containsKey(modelId) || _text.containsKey(modelId.replaceFirst('code-', ''));

  /// A wire is usable when a key can reach it. A direct, CORS-open wire needs a
  /// key in the browser bundle. A proxied wire needs only the proxy: the server
  /// holds that provider's key, so an empty local key is not a failure there.
  /// Requiring one anyway made every proxied model report "no-key" without the
  /// request ever leaving the device.
  bool _wireUsable(String w) {
    final t = _textWires[w]!;
    return t.cors ? t.key.isNotEmpty : _proxy.isNotEmpty;
  }

  /// One OpenAI-compatible call on a text wire. Throws a raw error string.
  Future<String> _textCall(String w, String remote, List<Map<String, String>> messages, {int? maxTokens}) async {
    final t = _textWires[w]!;
    final viaProxy = !t.cors;
    if (viaProxy) {
      if (_proxy.isEmpty) throw const MediaGenError('cors');
    } else if (t.key.isEmpty) {
      throw const MediaGenError('no-key');
    }
    final url = viaProxy ? '$_proxy/api/p?u=${_proxyRoute[w]}' : '${t.base}/chat/completions';
    try {
      final res = await _dio.post(url,
          data: {'model': _wireSlug(w, remote), 'messages': messages, if (maxTokens != null) 'max_tokens': maxTokens},
          options: Options(headers: viaProxy ? {'Content-Type': 'application/json'} : {'Content-Type': 'application/json', 'Authorization': 'Bearer ${t.key}'}, receiveTimeout: const Duration(seconds: 90)));
      final msg = res.data['choices']?[0]?['message'];
      final text = _stripThink(msg?['content'] as String? ?? '');
      if (text.isEmpty) throw const MediaGenError('empty');
      return text;
    } on DioException catch (e) {
      // NVIDIA's free tier sheds load with 503/429 for a moment; wait and let
      // the next attempt (the same model again) go out.
      final sc = e.response?.statusCode;
      if (w == 'nv' && (sc == 503 || sc == 429)) await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.connectionTimeout) throw const MediaGenError('timeout');
      throw MediaGenError('provider ${e.response?.statusCode ?? 'unreachable'}: ${_errBody(e)}');
    }
  }

  /// Pollinations' OpenAI-compatible text endpoint. Needs no key, so it is the
  /// floor every text route falls back to: the answer is a weaker model rather
  /// than nothing.
  ///
  /// Classic anonymous free tier currently exposes only `openai-fast` (alias
  /// `openai`). Multi-model Home sends N parallel chats that all land here when
  /// no provider keys are in the build; a burst of concurrent POSTs gets 402
  /// Payment Required. Serialize through [_pollinationsGate] and retry 402/429.
  Future<void>? _pollinationsGate;

  Future<String> _pollinationsText(List<Map<String, String>> messages) async {
    // Queue callers so consensus / multi-row Home do not stampede the free tier.
    while (_pollinationsGate != null) {
      try {
        await _pollinationsGate;
      } catch (_) {}
    }
    final done = Completer<void>();
    _pollinationsGate = done.future;
    try {
      return await _pollinationsTextOnce(messages);
    } finally {
      done.complete();
      if (identical(_pollinationsGate, done.future)) _pollinationsGate = null;
    }
  }

  Future<String> _pollinationsTextOnce(List<Map<String, String>> messages) async {
    Object? last;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (1 << (attempt - 1))));
      }
      try {
        final res = await _dio.post('https://text.pollinations.ai/openai',
            data: {'model': 'openai-fast', 'messages': messages},
            options: Options(headers: {'Content-Type': 'application/json'}));
        final text = _stripThink(res.data['choices']?[0]?['message']?['content'] as String? ?? '');
        if (text.trim().isEmpty) throw const MediaGenError('Pollinations returned an empty answer');
        return text;
      } on DioException catch (e) {
        last = e;
        final sc = e.response?.statusCode;
        if (sc == 402 || sc == 429 || sc == 503) continue;
        throw MediaGenError('Pollinations ${sc ?? 'unreachable'}: ${_errBody(e)}');
      }
    }
    if (last is DioException) {
      throw MediaGenError('Pollinations ${last.response?.statusCode ?? 'unreachable'}: ${_errBody(last)}');
    }
    throw MediaGenError('Pollinations unreachable: $last');
  }

  /// Tries each attempt in order; throws the first meaningful error. With
  /// [fallback] on, a failed chain still ends at the keyless floor rather than
  /// at nothing. The judge turns it off so it can move to the next model
  /// instead of quietly settling for the weakest one.
  Future<String> _chain(List<(String, String)> tries, List<Map<String, String>> messages,
      {int? maxTokens, bool fallback = true}) async {
    Object? first;
    for (final (w, remote) in tries) {
      if (!_wireUsable(w)) {
        first ??= MediaGenError(_textWires[w]!.cors ? 'no-key' : 'cors');
        continue;
      }
      try {
        return await _textCall(w, remote, messages, maxTokens: maxTokens);
      } catch (e) {
        if (first == null || '$first'.contains('no-key') || '$first'.contains('cors')) first = e;
      }
    }
    if (fallback) {
      try {
        return await _pollinationsText(messages);
      } catch (e) {
        if (first == null || '$first'.contains('no-key') || '$first'.contains('cors')) first = e;
      }
    }
    throw first ?? const MediaGenError('no-key');
  }

  /// The judge for the Consensus Agent and the Smart Gen agent. Walks
  /// [consensusModels] strongest first; each model is exhausted across all of
  /// its own provider backups before the next one is considered, and the
  /// keyless floor only runs once every one of them has failed. An outage on
  /// any single provider therefore costs nothing but latency.
  Future<String> consensus(List<Map<String, String>> messages) async {
    for (final id in consensusModels) {
      final tries = _text[id];
      if (tries == null) continue;
      try {
        return await _chain(tries, messages, fallback: false);
      } catch (_) {}
    }
    return _chain(const [], messages);
  }

  /// chat.ts hasCredentials: is there a key for the wire this route uses?
  /// Pollinations is keyless in the source (it now answers 402, D61).
  bool hasCredentials(String modelId) {
    final tx = _text[modelId.replaceFirst('code-', '')];
    if (tx != null) return tx.any((t) => _wireUsable(t.$1));
    final r = _routes[modelId];
    if (r == null) return false;
    if (r.provider == 'pollinations-image' || r.provider == 'pollinations-text') return true;
    return _wire(r).key.isNotEmpty;
  }

  Map<String, String> _headers(String key) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        'HTTP-Referer': 'https://collider.app',
        'X-Title': 'Collider',
      };

  /// chat.ts arToSize: long edge ~1024, portrait fallback.
  static ({int width, int height}) arToSize(String? ar) {
    const map = {
      '1:1': [1024, 1024], '16:9': [1344, 768], '9:16': [768, 1344], '4:3': [1152, 896], '3:4': [896, 1152],
      '3:2': [1216, 832], '2:3': [832, 1216], '4:5': [896, 1120], '5:4': [1120, 896], '21:9': [1536, 640],
    };
    final s = map[ar ?? '9:16'] ?? map['9:16']!;
    return (width: s[0], height: s[1]);
  }

  /// chat.ts generateImageUrl.
  static String pollinationsUrl(String prompt, GenFlags f, {String model = '', int? seed}) {
    // Free-tier Pollinations 402s large frames; keep the long edge ≤256.
    // Omit model= when empty — forcing flux/sana currently 402/503s the free tier.
    final full = arToSize(f.ar);
    final long = math.max(full.width, full.height);
    final scale = long > 256 ? 256 / long : 1.0;
    final w = math.max(128, (full.width * scale).round());
    final h = math.max(128, (full.height * scale).round());
    final sd = seed ?? math.Random().nextInt(1000000);
    final body = '${prompt.isEmpty ? 'abstract art' : prompt}${f.style != null && f.style != 'neutral' ? ', ${f.style}' : ''}';
    final neg = (f.negative ?? '').isNotEmpty ? '&negative=${Uri.encodeComponent(f.negative!)}' : '';
    final modelQ = model.isEmpty ? '' : '&model=$model';
    return 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(body)}?width=$w&height=$h&nologo=true$modelQ&seed=$sd$neg';
  }

  /// One generation for one model, exactly as the source's sendChat routes it.
  /// Throws [MediaGenError] when it cannot run (no key, provider refusal).
  Future<MediaResult> generate(String modelId, String prompt, GenFlags f, {List<String> imageDataUris = const []}) async {
    final r = _routes[modelId];
    if (r == null) throw const MediaGenError('not routed');
    if (!hasCredentials(modelId)) throw const MediaGenError('no credentials');
    try {
      switch (r.provider) {
        case 'pollinations-image':
          // Retry transient Pollinations 402/429/503 like the text floor.
          // When the free tier still refuses, fetch via the themes page proxy
          // (same origin path the app already trusts for catalog images).
          Object? last;
          for (var attempt = 0; attempt < 4; attempt++) {
            try {
              final url = pollinationsUrl(prompt, f, model: r.remote, seed: math.Random().nextInt(1000000));
              final tryUrls = <String>[
                url,
                if (attempt >= 1)
                  'https://collider-themes.ebridavid.workers.dev/page?url=${Uri.encodeComponent(url)}',
              ];
              DioException? inner;
              for (final u in tryUrls) {
                try {
                  final res = await _dio.get<List<int>>(u, options: Options(responseType: ResponseType.bytes));
                  final ct = res.headers.value('content-type') ?? 'image/jpeg';
                  if (!ct.startsWith('image/')) throw const MediaGenError('no image');
                  return MediaResult('image', url: 'data:$ct;base64,${base64Encode(res.data!)}');
                } on DioException catch (e) {
                  inner = e;
                  final code = e.response?.statusCode ?? 0;
                  if (code != 402 && code != 429 && code != 503) rethrow;
                }
              }
              last = inner;
              await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
            } on DioException catch (e) {
              last = e;
              final code = e.response?.statusCode ?? 0;
              if (code != 402 && code != 429 && code != 503) rethrow;
              await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
            }
          }
          throw MediaGenError('provider ${(last is DioException) ? (last.response?.statusCode ?? 'unreachable') : 'unreachable'}');
        case 'openrouter-image':
          return MediaResult('image', url: await _image(r, prompt, f, imageDataUris));
        case 'openrouter-video':
          return MediaResult('video', url: await _video(r, prompt, f, imageDataUris));
        case 'openrouter-speech':
          return MediaResult('audio', url: await _speech(r, prompt, f));
        case 'openrouter-audio':
          final p = f.task == 'sound-effect' ? 'A short sound effect, no music, no melody, no vocals: $prompt' : prompt;
          return MediaResult('audio', url: await _audio(r, p, f));
        case 'openrouter':
          return MediaResult('text', text: await chat(modelId, [
            {'role': 'system', 'content': 'You are Collider, a concise, helpful assistant.'},
            {'role': 'user', 'content': prompt},
          ]));
      }
    } on DioException catch (e) {
      throw MediaGenError('provider ${e.response?.statusCode ?? 'unreachable'}');
    }
    throw const MediaGenError('not routed');
  }

  /// callOpenRouter (non-streaming): text answer for General / Coding.
  Future<String> chat(String modelId, List<Map<String, String>> messages) async {
    final tx = _text[modelId.replaceFirst('code-', '')];
    if (tx != null) {
      try {
        return await _chain(tx, messages);
      } catch (e) {
        throw MediaGenError(friendlyErrorMessage(e));
      }
    }
    final r = _routes[modelId];
    if (r == null) throw const MediaGenError('this model has no chat route in this build');
    if (r.provider == 'pollinations-text') return _pollinationsText(messages);
    if (r.provider != 'openrouter') throw const MediaGenError('this model has no chat route in this build');
    if (!hasCredentials(modelId)) throw const MediaGenError('no OpenRouter API key in this build');
    final w = _wire(r);
    try {
      final res = await _dio.post('${w.base}/chat/completions',
          data: {'model': _slug(r), 'messages': messages}, options: Options(headers: _headers(w.key)));
      final text = res.data['choices']?[0]?['message']?['content'] as String? ?? '';
      if (text.trim().isEmpty) throw const MediaGenError('provider returned an empty answer');
      return text;
    } on DioException catch (e) {
      throw MediaGenError('provider ${e.response?.statusCode ?? 'unreachable'}: ${_errBody(e)}');
    }
  }

  static String _errBody(DioException e) {
    final d = e.response?.data;
    if (d is Map) return '${d['error'] is Map ? d['error']['message'] : d['error'] ?? d['message'] ?? d}';
    if (d is String && d.isNotEmpty) return d.length > 200 ? d.substring(0, 200) : d;
    return e.message ?? e.type.name;
  }

  // callOpenRouterImage
  Future<String> _image(_Route r, String prompt, GenFlags f, List<String> refs) async {
    final w = _wire(r);
    final size = arToSize(f.ar);
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      for (final u in refs.take(16)) {'type': 'image_url', 'image_url': {'url': u}},
    ];
    final res = await _dio.post('${w.base}/chat/completions',
        data: {
          'model': _slug(r),
          'messages': [
            {'role': 'user', 'content': refs.isNotEmpty ? content : prompt}
          ],
          'modalities': ['image', 'text'],
          'image_size': {'width': size.width, 'height': size.height},
          if (f.ar != null) 'aspect_ratio': f.ar,
          if (f.quality != null && f.quality != 'standard') 'quality': f.quality,
          if ((f.negative ?? '').isNotEmpty) 'negative_prompt': f.negative,
          if (f.resolution != null) 'resolution': f.resolution,
          if (f.background != null) 'background': f.background,
        },
        options: Options(headers: _headers(w.key)));
    final url = res.data['choices']?[0]?['message']?['images']?[0]?['image_url']?['url'] as String?;
    if (url == null || url.isEmpty) throw const MediaGenError('no image');
    return url;
  }

  // callOpenRouterVideo: create -> poll -> download.
  Future<String> _video(_Route r, String prompt, GenFlags f, List<String> frames) async {
    final w = _wire(r);
    final create = await _dio.post('${w.base}/videos',
        data: {
          'model': _slug(r),
          'prompt': prompt.isEmpty ? 'a short abstract scene' : prompt,
          'duration': f.duration ?? 4,
          'aspect_ratio': f.ar,
          if (f.quality != null) 'resolution': f.quality,
          if (frames.isNotEmpty) 'first_frame_image': frames.first,
          if (f.task == 'keyframe-video' && frames.length > 1) 'last_frame_image': frames[1],
        },
        options: Options(headers: _headers(w.key)));
    final job = create.data as Map;
    final pollUrl = (job['polling_url'] as String?) ?? '${w.base}/videos/${job['id']}';
    var status = (job['status'] as String?) ?? 'queued';
    String? contentUrl = (job['unsigned_urls'] as List?)?.cast<String>().firstOrNull;
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    const terminal = {'completed', 'failed', 'error', 'cancelled'};
    while (!terminal.contains(status) && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 8));
      final p = await _dio.get(pollUrl, options: Options(headers: {'Authorization': 'Bearer ${w.key}'}));
      status = p.data['status'] as String? ?? 'failed';
      contentUrl = (p.data['unsigned_urls'] as List?)?.cast<String>().firstOrNull;
    }
    if (status != 'completed' || contentUrl == null) throw MediaGenError('video $status');
    final file = await _dio.get<List<int>>(contentUrl,
        options: Options(responseType: ResponseType.bytes, headers: {'Authorization': 'Bearer ${w.key}'}));
    return 'data:video/mp4;base64,${base64Encode(file.data!)}';
  }

  // callOpenRouterSpeech: raw audio bytes back.
  Future<String> _speech(_Route r, String text, GenFlags f) async {
    final w = _wire(r);
    final format = f.format ?? 'mp3';
    final voice = f.voice ?? r.voice;
    final res = await _dio.post<List<int>>('${w.base}/audio/speech',
        data: {'model': _slug(r), 'input': text.isEmpty ? 'Hello from Collider.' : text, if (voice != null) 'voice': voice, 'response_format': format},
        options: Options(headers: _headers(w.key), responseType: ResponseType.bytes));
    final bytes = Uint8List.fromList(res.data ?? const []);
    if (bytes.isEmpty) throw const MediaGenError('no audio');
    return 'data:audio/$format;base64,${base64Encode(bytes)}';
  }

  // callOpenRouterAudio: streamed SSE, base64 audio chunks concatenated.
  Future<String> _audio(_Route r, String prompt, GenFlags f) async {
    final w = _wire(r);
    final finalPrompt = '${prompt.isEmpty ? 'a short instrumental piece' : prompt}.\nOptions:\n- Vocals: ${f.vocals ?? 'vocal'}\n- Quality: ${f.bitrate ?? 'standard'}\n- Format: ${f.format ?? 'mp3'}\n- Genre/Style tags: ';
    final res = await _dio.post<String>('${w.base}/chat/completions',
        data: {
          'model': _slug(r),
          'messages': [
            {'role': 'user', 'content': finalPrompt}
          ],
          'modalities': ['audio', 'text'],
          'stream': true,
        },
        options: Options(headers: _headers(w.key), responseType: ResponseType.plain));
    final b = StringBuffer();
    for (final line in (res.data ?? '').split('\n')) {
      if (!line.startsWith('data: ') || line.contains('[DONE]')) continue;
      try {
        final piece = jsonDecode(line.substring(6))['choices']?[0]?['delta']?['audio']?['data'];
        if (piece is String) b.write(piece);
      } catch (_) {}
    }
    if (b.isEmpty) throw const MediaGenError('no audio');
    return 'data:audio/mp3;base64,$b';
  }
}
