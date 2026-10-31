import 'package:flutter/material.dart';

// v8.3 media restore: a straight port of the source app's roster
// (collidermergedx3-glm/src/models.ts): the same five categories, the same
// models with the same ids, names, tiers, credit weights and colours. D35 is
// revoked; nothing here is invented.
enum ModelCategory { general, image, video, audio, coding }

extension ModelCategoryX on ModelCategory {
  /// models.ts CATEGORIES labels.
  String get label => switch (this) {
        ModelCategory.general => 'General',
        ModelCategory.image => 'Image',
        ModelCategory.video => 'Video',
        ModelCategory.audio => 'Audio',
        ModelCategory.coding => 'Coding',
      };
  bool get isMedia => this == ModelCategory.image || this == ModelCategory.video || this == ModelCategory.audio;
}

enum ModelTier { free, pro, elite }

/// models.ts TIER_RANK / TIER_INFO.
class TierInfo {
  final String label;
  final int pool;
  final String price;
  final Color color;
  const TierInfo(this.label, this.pool, this.price, this.color);
  static const Map<ModelTier, TierInfo> all = {
    ModelTier.free: TierInfo('Free', 0, '\$0', Color(0xFFE2E8F0)),
    ModelTier.pro: TierInfo('Pro', 3000, '\$19.99/mo', Color(0xFFDC2626)),
    ModelTier.elite: TierInfo('Elite', 7500, '\$49.99/mo', Color(0xFFF5E000)),
  };
  static int rank(ModelTier t) => t.index;
}

class ModelDef {
  final String id;
  /// Full model name exactly as the source roster writes it. No short forms.
  final String label;
  final String provider;
  /// models.ts `desc` (kept as data; not shown as helper copy).
  final String desc;
  final ModelTier tier;
  final List<ModelCategory> categories;
  /// Credits per call for the model's reference output (models.ts `weight`).
  final int weight;
  final Color providerColor;

  const ModelDef({
    required this.id,
    required this.label,
    required this.provider,
    this.desc = '',
    required this.tier,
    required this.categories,
    this.weight = 1,
    required this.providerColor,
  });

  ModelCategory get category => categories.isEmpty ? ModelCategory.general : categories.first;
  bool get isMedia => categories.any((c) => c.isMedia);
}

class ModelRoster {
  /// models.ts MODELS, in source order.
  static const List<ModelDef> source = [
    ModelDef(id: 'free/glm-5-3-flash', label: 'GLM 5.3 Flash', provider: 'Z.ai', desc: 'Zhipu\'s fast flagship.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFF6EA8FF)),
    ModelDef(id: 'free/laguna-s-2-1', label: 'Laguna S 2.1', provider: 'Poolside', desc: 'Poolside. Code-capable generalist.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFF4FD1C5)),
    ModelDef(id: 'free/laguna-xs-2-1', label: 'Laguna XS 2.1', provider: 'Poolside', desc: 'Poolside\'s compact model.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFF7DE3D8)),
    ModelDef(id: 'free/ling-3-1-flash', label: 'Ling 3.1 Flash', provider: 'inclusionAI', desc: 'InclusionAI. Fastest responder in the roster.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFFB794F4)),
    ModelDef(id: 'free/nemotron-3-5-lightning', label: 'Nemotron 3.5 Lightning', provider: 'NVIDIA', desc: 'NVIDIA\'s fast reasoning model.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 1, providerColor: Color(0xFF76D672)),
    ModelDef(id: 'pro/glm-5-3', label: 'GLM 5.3', provider: 'Z.ai', desc: 'Zhipu\'s flagship.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 2, providerColor: Color(0xFF3D7BFF)),
    ModelDef(id: 'pro/deepseek-4-1-flash', label: 'DeepSeek V4.1 Flash', provider: 'DeepSeek', desc: 'DeepSeek\'s current fast model.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 2, providerColor: Color(0xFF5B8CFF)),
    ModelDef(id: 'pro/minimax-m3', label: 'MiniMax M3.1 Flash', provider: 'MiniMax', desc: 'MiniMax M3.1 Flash — Genie & consensus agent 1.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 2, providerColor: Color(0xFFFF9E6B)),
    ModelDef(id: 'pro/mimo-v2-6-flash', label: 'MiMo V2.6 Flash', provider: 'Xiaomi', desc: 'Xiaomi\'s fast long-context model.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 2, providerColor: Color(0xFFFF7A45)),
    ModelDef(id: 'pro/nemotron-3-ultra', label: 'Nemotron 3 Ultra', provider: 'NVIDIA', desc: 'NVIDIA\'s flagship open model.', tier: ModelTier.pro, categories: [ModelCategory.general], weight: 3, providerColor: Color(0xFF9BE15D)),
    ModelDef(id: 'elite/kimi-k3', label: 'Kimi K3', provider: 'Moonshot AI', desc: 'Moonshot\'s flagship. Deepest reasoning.', tier: ModelTier.elite, categories: [ModelCategory.general], weight: 6, providerColor: Color(0xFF4BE6B1)),
    ModelDef(id: 'code-free/glm-5-3-flash', label: 'GLM 5.3 Flash', provider: 'Z.ai', desc: 'Zhipu\'s fast flagship.', tier: ModelTier.free, categories: [ModelCategory.coding], weight: 1, providerColor: Color(0xFF6EA8FF)),
    ModelDef(id: 'code-free/laguna-s-2-1', label: 'Laguna S 2.1', provider: 'Poolside', desc: 'Poolside. Code-capable generalist.', tier: ModelTier.free, categories: [ModelCategory.coding], weight: 1, providerColor: Color(0xFF4FD1C5)),
    ModelDef(id: 'code-free/laguna-xs-2-1', label: 'Laguna XS 2.1', provider: 'Poolside', desc: 'Poolside\'s compact model.', tier: ModelTier.free, categories: [ModelCategory.coding], weight: 1, providerColor: Color(0xFF7DE3D8)),
    ModelDef(id: 'code-free/ling-3-1-flash', label: 'Ling 3.1 Flash', provider: 'inclusionAI', desc: 'InclusionAI. Fastest responder in the roster.', tier: ModelTier.free, categories: [ModelCategory.coding], weight: 1, providerColor: Color(0xFFB794F4)),
    ModelDef(id: 'code-free/nemotron-3-5-lightning', label: 'Nemotron 3.5 Lightning', provider: 'NVIDIA', desc: 'NVIDIA\'s fast reasoning model.', tier: ModelTier.free, categories: [ModelCategory.coding], weight: 1, providerColor: Color(0xFF76D672)),
    ModelDef(id: 'code-pro/glm-5-3', label: 'GLM 5.3', provider: 'Z.ai', desc: 'Zhipu\'s flagship.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 2, providerColor: Color(0xFF3D7BFF)),
    ModelDef(id: 'code-pro/deepseek-4-1-flash', label: 'DeepSeek V4.1 Flash', provider: 'DeepSeek', desc: 'DeepSeek\'s current fast model.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 2, providerColor: Color(0xFF5B8CFF)),
    ModelDef(id: 'code-pro/minimax-m3', label: 'MiniMax M3.1 Flash', provider: 'MiniMax', desc: 'MiniMax M3.1 Flash — Genie & consensus agent 1.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 2, providerColor: Color(0xFFFF9E6B)),
    ModelDef(id: 'code-pro/mimo-v2-6-flash', label: 'MiMo V2.6 Flash', provider: 'Xiaomi', desc: 'Xiaomi\'s fast long-context model.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 2, providerColor: Color(0xFFFF7A45)),
    ModelDef(id: 'code-pro/nemotron-3-ultra', label: 'Nemotron 3 Ultra', provider: 'NVIDIA', desc: 'NVIDIA\'s flagship open model.', tier: ModelTier.pro, categories: [ModelCategory.coding], weight: 3, providerColor: Color(0xFF9BE15D)),
    ModelDef(id: 'code-elite/kimi-k3', label: 'Kimi K3', provider: 'Moonshot AI', desc: 'Moonshot\'s flagship. Deepest reasoning.', tier: ModelTier.elite, categories: [ModelCategory.coding], weight: 6, providerColor: Color(0xFF4BE6B1)),
    ModelDef(id: 'img/flux-free', label: 'FLUX', provider: 'Black Forest Labs', desc: 'Fast, free-to-generate image model.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 1, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'img/gemini-3-1-flash-image', label: 'Gemini 3.1 Flash Image', provider: 'Google', desc: 'Google\'s fast image generator.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 5, providerColor: Color(0xFF7FD8C4)),
    ModelDef(id: 'img/gpt-5-image-mini', label: 'GPT-5 Image Mini', provider: 'OpenAI', desc: 'OpenAI\'s compact image model.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 2, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'img/flux-2-klein', label: 'FLUX.2 Klein', provider: 'Black Forest Labs', desc: 'Fastest FLUX.2 tier; high-throughput.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 5, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'img/nano-banana-2', label: 'Nano Banana 2', provider: 'Google', desc: 'Google\'s image model.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 19, providerColor: Color(0xFFF5E000)),
    ModelDef(id: 'img/kling-3-image', label: 'Kling 3.0 Image', provider: 'Kuaishou', desc: 'Kuaishou. Fast image generation.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 13, providerColor: Color(0xFF84CC16)),
    ModelDef(id: 'img/gpt-image-2', label: 'GPT Image 2', provider: 'OpenAI', desc: 'OpenAI\'s current image model.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 19, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'img/seedream-5-0', label: 'Seedream 5.0', provider: 'ByteDance', desc: 'ByteDance\'s newest.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 16, providerColor: Color(0xFFF0A35E)),
    ModelDef(id: 'img/qwen-image-2-0', label: 'Qwen Image 2.0', provider: 'Alibaba', desc: 'Alibaba.', tier: ModelTier.pro, categories: [ModelCategory.image], weight: 15, providerColor: Color(0xFFC9A7FF)),
    ModelDef(id: 'img/dall-e-3', label: 'DALL·E 3', provider: 'OpenAI', desc: 'OpenAI\'s classic.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 20, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'img/mj-upscale', label: 'Midjourney Upscale', provider: 'Midjourney', desc: 'Upscales a Midjourney render.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 25, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'img/nano-banana-pro', label: 'Nano Banana Pro', provider: 'Google', desc: 'Top Nano Banana tier.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 37, providerColor: Color(0xFFF5E000)),
    ModelDef(id: 'img/gemini-3-pro-image', label: 'Gemini 3 Pro Image', provider: 'Google', desc: 'Google\'s flagship image model.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 67, providerColor: Color(0xFF7FD8C4)),
    ModelDef(id: 'img/flux-2-max', label: 'FLUX.2 Max', provider: 'Black Forest Labs', desc: 'Black Forest Labs\' top tier; peak fidelity.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 10, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'img/gpt-5-4-image-2', label: 'GPT-5.4 Image 2', provider: 'OpenAI', desc: 'OpenAI\'s newest image model, GPT Image 2.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 10, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'img/seedream-4-5', label: 'Seedream 4.5', provider: 'ByteDance', desc: 'ByteDance; strong editing consistency.', tier: ModelTier.elite, categories: [ModelCategory.image], weight: 20, providerColor: Color(0xFFF0A35E)),
    ModelDef(id: 'vid/veo-3-1-lite', label: 'Veo 3.1 Lite', provider: 'Google', desc: 'Lightweight video generation.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 75, providerColor: Color(0xFFFF6BA0)),
    ModelDef(id: 'vid/wan-2-6', label: 'Wan 2.6', provider: 'Alibaba', desc: 'Multi-shot, native audio, 480p–1080p.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 100, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'vid/grok-imagine-video', label: 'Grok Imagine Video', provider: 'xAI', desc: 'xAI; 7 aspect ratios, 1–15s clips.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 125, providerColor: Color(0xFF4DCAFF)),
    ModelDef(id: 'vid/kling-3-standard', label: 'Kling Video v3.0', provider: 'Kuaishou', desc: 'Start+end keyframes, native audio, to 15s.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 211, providerColor: Color(0xFF84CC16)),
    ModelDef(id: 'vid/wan-2-2-flash', label: 'Wan 2.2 Flash', provider: 'Alibaba', desc: '480p–1080p, image-to-video.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 36, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'vid/wan-2-2-plus', label: 'Wan 2.2 Plus', provider: 'Alibaba', desc: 'Text-to-video, 480p and 1080p.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 50, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'vid/kling-2-5-turbo', label: 'Kling 2.5 Turbo', provider: 'Kuaishou', desc: '720p–4K. t2v, i2v, keyframes and reference.', tier: ModelTier.pro, categories: [ModelCategory.video], weight: 90, providerColor: Color(0xFF84CC16)),
    ModelDef(id: 'vid/hailuo-2-3', label: 'Hailuo 2.3', provider: 'MiniMax', desc: 'MiniMax; native 1080p, 6s and 10s.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 205, providerColor: Color(0xFFFF9E6B)),
    ModelDef(id: 'vid/veo-3-1-fast', label: 'Veo 3.1 Fast', provider: 'Google', desc: 'Veo quality with 4K.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 200, providerColor: Color(0xFFFF6BA0)),
    ModelDef(id: 'vid/veo-3', label: 'Veo 3.1', provider: 'Google', desc: 'Flagship fidelity. 4K, native synced audio.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 500, providerColor: Color(0xFFFF6BA0)),
    ModelDef(id: 'vid/sora-2', label: 'Sora 2 Pro', provider: 'OpenAI', desc: 'Up to 20s, synced audio. The longest clips.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 750, providerColor: Color(0xFF3B82F6)),
    ModelDef(id: 'vid/wan-2-5-preview', label: 'Wan 2.5 Preview', provider: 'Alibaba', desc: 'Newest Wan. 480p–1080p text-to-video.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 108, providerColor: Color(0xFFA78BFA)),
    ModelDef(id: 'vid/kling-3-turbo', label: 'Kling 3.0 Turbo', provider: 'Kuaishou', desc: 'Kling\'s flagship. Up to 4K, keyframes.', tier: ModelTier.elite, categories: [ModelCategory.video], weight: 179, providerColor: Color(0xFF84CC16)),
    ModelDef(id: 'aud/lyria-3-clip', label: 'Lyria 3 Clip', provider: 'Google', desc: '30s AI-generated instrumental/vocal clip.', tier: ModelTier.pro, categories: [ModelCategory.audio], weight: 15, providerColor: Color(0xFFFF69C8)),
    ModelDef(id: 'aud/kokoro-82m', label: 'Kokoro 82M', provider: 'hexgrad', desc: 'Lightweight TTS; 8 languages, 54 preset voices.', tier: ModelTier.pro, categories: [ModelCategory.audio], weight: 1, providerColor: Color(0xFF8EE878)),
    ModelDef(id: 'aud/gpt-audio-mini', label: 'GPT Audio Mini', provider: 'OpenAI', desc: 'Conversational voice output, low latency.', tier: ModelTier.pro, categories: [ModelCategory.audio], weight: 5, providerColor: Color(0xFFD9D3C7)),
    ModelDef(id: 'aud/sesame-csm-1b', label: 'Sesame CSM 1B', provider: 'Sesame', desc: 'Conversational speech — dialogue-tuned, not narration.', tier: ModelTier.pro, categories: [ModelCategory.audio], weight: 4, providerColor: Color(0xFF9ECBFF)),
    ModelDef(id: 'aud/lyria-3-pro', label: 'Lyria 3 Pro', provider: 'Google', desc: 'Full AI-generated song, up to ~3 min, vocals.', tier: ModelTier.elite, categories: [ModelCategory.audio], weight: 30, providerColor: Color(0xFFFF8A65)),
    ModelDef(id: 'aud/gemini-3-1-flash-tts', label: 'Gemini 3.1 Flash TTS', provider: 'Google', desc: '70+ languages, 200+ emotion tags, 2 speakers.', tier: ModelTier.elite, categories: [ModelCategory.audio], weight: 5, providerColor: Color(0xFF7FD8C4)),
    ModelDef(id: 'aud/voxtral-mini-tts', label: 'Voxtral Mini TTS', provider: 'Mistral AI', desc: 'Zero-shot voice cloning, multilingual.', tier: ModelTier.elite, categories: [ModelCategory.audio], weight: 6, providerColor: Color(0xFFF0A35E)),
    ModelDef(id: 'aud/gpt-audio', label: 'GPT Audio', provider: 'OpenAI', desc: 'OpenAI\'s flagship conversational audio model.', tier: ModelTier.elite, categories: [ModelCategory.audio], weight: 25, providerColor: Color(0xFFD9D3C7)),
  ];

  /// Live roster. Starts as the source roster. When the Collider server
  /// answers, its text models replace the General list; every other
  /// category stays exactly as the source has it (as before commit 8a0ae71).
  static List<ModelDef> allModels = List.of(source);

  static void setLive(List<ModelDef> live) {
    allModels = [...live, ...source.where((m) => !m.categories.contains(ModelCategory.general))];
  }

  /// models.ts modelsForCategory: tier first, then weight.
  static List<ModelDef> forCategory(ModelCategory category) {
    // Stable, like Array.prototype.sort: ties keep roster order.
    final l = allModels.where((m) => m.categories.contains(category)).toList();
    final idx = {for (var i = 0; i < l.length; i++) l[i].id: i};
    l.sort((a, b) {
      final t = a.tier.index - b.tier.index;
      if (t != 0) return t;
      final w = a.weight - b.weight;
      return w != 0 ? w : idx[a.id]! - idx[b.id]!;
    });
    return l;
  }

  static ModelDef? byId(String id) {
    for (final m in allModels) {
      if (m.id == id) return m;
    }
    for (final m in source) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// models.ts CATEGORY_MIN_TIER / effectiveMinTier.
  static ModelTier effectiveMinTier(ModelDef m) {
    const catMin = {
      ModelCategory.image: ModelTier.pro,
      ModelCategory.video: ModelTier.pro,
      ModelCategory.audio: ModelTier.pro,
      ModelCategory.coding: ModelTier.pro,
    };
    var min = ModelTier.free;
    for (final c in m.categories) {
      final t = catMin[c];
      if (t != null && t.index > min.index) min = t;
    }
    return min.index > m.tier.index ? min : m.tier;
  }

  /// models.ts canUse.
  static bool canUse(ModelTier tier, ModelDef m) => tier.index >= effectiveMinTier(m).index;
}
