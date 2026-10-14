import '../theme/app_font.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'materialize.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../theme/edge_fade.dart';
import '../theme/specular_border.dart';
import 'vision_tokens.dart';

export 'vision_tokens.dart';
export '../theme/edge_fade.dart';
export 'md_text.dart';

/// Glass material levels, mapped to the Collider depth planes.
enum VMaterial { prompt, resting, elevated, modal, work }

/// v9.1.1: THE glass recipe, used by every floating panel. Strong backdrop
/// blur, a ~10 % white frost, no outline, no painted gradient, a soft shadow
/// so the edge fades into the wallpaper.
class VFrost {
  // v9.1.3: solid, physically present glass: a clear dark tint (~48 %), a
  // slight frost and a slight blur. Reads as an object, never a hologram.
  static const double blur = 14;
  static const Color tint = Color(0xD018181E);
  // v9.1.6: full-screen work surfaces (Music, Smart Gen, Files, Market) are a
  // touch clearer so the ticker stays visible behind them, blurred.
  static const Color workTint = Color(0x6618181E);
  static const List<BoxShadow> shadow = [BoxShadow(color: Color(0x29000000), blurRadius: 40, spreadRadius: -8, offset: Offset(0, 10))];
}

extension VMaterialX on VMaterial {
  // v9.1.2: full frost only on temporary surfaces (modal); persistent
  // chrome (prompt / resting / elevated / work) gets a light blur, no tint.
  bool get frosted => true; // v9.1.3: one material on every floating surface
  Color get fill => frosted ? VFrost.tint : const Color(0x00000000);
  double get blur => frosted ? VFrost.blur : 10;
  Color get rim => const Color(0x00000000);
  List<BoxShadow> get shadow => frosted ? VFrost.shadow : const [];
}

/// One-pass glass surface: blur + material fill + hairline + specular rim.
/// Never nest a VGlass inside another VGlass; use plain fills inside.
class VGlass extends StatelessWidget {
  final Widget child;
  final VMaterial material;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? fill;
  final bool shadow;

  const VGlass({
    super.key,
    required this.child,
    this.material = VMaterial.resting,
    this.radius = VRadius.card,
    this.padding = EdgeInsets.zero,
    this.fill,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: shadow ? material.shadow : null),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: material.blur * Materialize.of(context), sigmaY: material.blur * Materialize.of(context)),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(color: fill ?? material.fill, borderRadius: r),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Click-away layer behind an overlay: a light, unblurred dim (VOverlay.scrim)
/// so the wallpaper and resting content stay readable around the menu.
class VScrim extends StatelessWidget {
  final VoidCallback? onTap;
  final bool blur;
  // Focus windows push the world back with depth of field: blur by default.
  const VScrim({super.key, this.onTap, this.blur = true});

  @override
  Widget build(BuildContext context) {
    final dim = Container(color: VDepth.dim);
    // v9.1.6: the backdrop blur follows the materialize progress, so it fades
    // with the layer instead of cutting in/out at full strength.
    final k = Materialize.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: blur
          ? BackdropFilter(filter: ImageFilter.blur(sigmaX: VDepth.blur * k, sigmaY: VDepth.blur * k), child: dim)
          : dim,
    );
  }
}

/// Click-away layer for a panel that should not disturb the world behind it.
///
/// [VScrim] dims uniformly and optionally blurs, which is right for a focus
/// window. It is wrong for a small, light control like the settings menu: that
/// has no standing to push the whole world out of focus. This fades darkness
/// in from the edges and leaves the middle clear, so the menu reads crisply on
/// a quiet field and the wallpaper survives at the centre.
class EdgeVignette extends StatelessWidget {
  final VoidCallback? onTap;

  /// How dark the corners get.
  final double strength;

  /// Fraction of the shortest side kept fully clear.
  final double clearRadius;

  const EdgeVignette({
    super.key,
    this.onTap,
    this.strength = 0.62,
    this.clearRadius = 0.34,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              // Radius is measured against the shortest side, so the clear
              // centre stays circular on a tall phone instead of stretching.
              radius: 1 / (clearRadius * 2),
              colors: [
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: strength * 0.45),
                Colors.black.withValues(alpha: strength),
              ],
              stops: [0.0, clearRadius, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Press physics from the kit: scale 0.97, opacity 0.9.
class VPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  const VPress({super.key, required this.child, this.onTap, this.tooltip});

  @override
  State<VPress> createState() => _VPressState();
}

class _VPressState extends State<VPress> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget w = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled
            ? (_) {
                setState(() => _down = true);
                HapticFeedback.selectionClick();
              }
            : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        child: AnimatedScale(
          scale: _down ? VMotion.pressedScale : 1,
          duration: VMotion.fast,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _down ? VMotion.pressedOpacity : 1,
            duration: VMotion.fast,
            child: widget.child,
          ),
        ),
      ),
    );
    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      w = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 400), child: w);
    }
    return w;
  }
}

/// Circular glass icon button (close, back, more, rail and dock items).
class VCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool selected;
  final bool floating; // own blur when floating directly over the wallpaper
  final String? tooltip;
  final Color? iconColor;

  const VCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 36,
    this.selected = false,
    this.floating = false,
    this.tooltip,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? VColors.fillActive : (floating ? VColors.glassElevated : VColors.fillCell),
        border: Border.all(color: selected ? VColors.borderHeavy : VColors.borderLight, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.46,
        color: iconColor ?? (selected ? VColors.textPrimary : VColors.textSecondary),
      ),
    );
    final body = floating
        ? ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: VBlur.medium, sigmaY: VBlur.medium),
              child: core,
            ),
          )
        : core;
    return Semantics(button: true, label: tooltip, child: VPress(onTap: onTap, tooltip: tooltip, child: icon == Icons.close_rounded && size < 44 ? SizedBox(width: 44, height: 44, child: Center(child: body)) : body));
  }
}

/// v9.1.4 (playtest #15): category picker as one crisp horizontal row of
/// plain names (format tags such as "mp4" are not categories).
class VCategoryRow extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;
  const VCategoryRow({super.key, required this.items, required this.selected, required this.onSelected});
  static const formatTags = {'mp4', 'webm', 'mov', 'jpg', 'jpeg', 'png', 'gif', '4k', '1080p', '720p', 'hd', 'live wallpaper', 'video', 'image'};
  static String plain(String c) => c.split(RegExp(r'[\s_-]+')).map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  @override
  Widget build(BuildContext context) {
    final shown = items.where((c) => !formatTags.contains(c.toLowerCase())).toList();
    return SizedBox(
      height: 44,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
        for (final c in shown)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(c),
            child: Container(
              height: 36,
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c == selected ? const Color(0xE6FFFFFF) : const Color(0xD018181E), borderRadius: BorderRadius.circular(18)),
              child: Text(plain(c), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c == selected ? const Color(0xFF111111) : Colors.white)),
            ),
          ),
      ]),
    );
  }
}

/// v9.1.4 (playtest #9): the one close control for every temporary view:
/// a 44 pt target with a frosted 36 pt circle, same corner everywhere.
class VCloseButton extends StatelessWidget {
  final VoidCallback? onTap;
  const VCloseButton({super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Close',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 36,
                    height: 36,
                    color: const Color(0xD018181E),
                    alignment: Alignment.center,
                    child: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

enum VButtonVariant { primary, secondary, ghost, destructive }

/// Kit Button: height 48 (36 dense), capsule, label 15/500.
class VButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VButtonVariant variant;
  final bool dense;
  final bool expand;

  const VButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.variant = VButtonVariant.secondary,
    this.dense = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (variant) {
      VButtonVariant.primary => (VColors.accentBlue, Colors.white, Colors.transparent),
      VButtonVariant.destructive => (VColors.accentRed, Colors.white, Colors.transparent),
      VButtonVariant.secondary => (VColors.overlayLight, VColors.textPrimary, VColors.borderLight),
      VButtonVariant.ghost => (Colors.transparent, VColors.textPrimary, Colors.transparent),
    };
    final h = dense ? 36.0 : 48.0;
    return VPress(
      onTap: onTap,
      child: Container(
        height: h,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: dense ? VSpace.md : VSpace.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(VRadius.full),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 15 : 17, color: fg),
              const SizedBox(width: VSpace.xs - 2),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VType.callout(color: fg, weight: FontWeight.w600).copyWith(fontSize: dense ? VType.sm : VType.md),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating capsule ornament (dock, toolbars, transport, URL bar).
class VOrnament extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Axis axis;
  const VOrnament({super.key, required this.child, this.padding = const EdgeInsets.all(6), this.axis = Axis.horizontal});

  @override
  Widget build(BuildContext context) {
    return VGlass(
        material: VMaterial.elevated,
        radius: VRadius.full,
        padding: padding,
        child: child,
      );
  }
}

class VRailItem {
  final IconData icon;
  final String label;
  const VRailItem(this.icon, this.label);
}

/// Vertical tab-bar ornament: circles in a glass capsule.
class VOrnamentRail extends StatelessWidget {
  final List<VRailItem> items;
  final int active;
  final ValueChanged<int> onSelect;
  final double size;
  const VOrnamentRail({super.key, required this.items, required this.active, required this.onSelect, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return VOrnament(
      padding: const EdgeInsets.all(VSpace.xxs + 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: VSpace.xs - 2),
            VCircleButton(
              icon: items[i].icon,
              tooltip: items[i].label,
              size: size,
              selected: i == active,
              onTap: () => onSelect(i),
            ),
          ],
        ],
      ),
    );
  }
}

/// Segmented capsule (bottom ornament tabs, filters). Scrolls when it overflows.
class VSegmented extends StatelessWidget {
  final List<String> labels;
  final int active;
  final ValueChanged<int> onSelect;
  final bool ornament; // true: floating glass capsule; false: recessed in-window track
  final bool dense; // tighter label padding, so a long tab row fits 430 px (D27)
  const VSegmented({super.key, required this.labels, required this.active, required this.onSelect, this.ornament = true, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < labels.length; i++)
            VPress(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: VMotion.fast,
                height: 32,
                padding: EdgeInsets.symmetric(horizontal: dense ? VSpace.xs : VSpace.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == active ? VColors.fillActive : Colors.transparent,
                  borderRadius: BorderRadius.circular(VRadius.full),
                ),
                child: Text(
                  labels[i],
                  style: VType.callout(
                    color: i == active ? VColors.textPrimary : VColors.textSecondary,
                    weight: i == active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (ornament) return VOrnament(padding: const EdgeInsets.all(VSpace.xxs), child: row);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: VColors.fillRecessed, borderRadius: BorderRadius.circular(VRadius.full)),
      child: row,
    );
  }
}

/// Filter chip (capsule).
class VChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? dot;
  const VChip({super.key, required this.label, this.selected = false, this.onTap, this.dot});

  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VMotion.fast,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
        decoration: BoxDecoration(
          color: selected ? VColors.fillActive : VColors.fillCell,
          borderRadius: BorderRadius.circular(VRadius.full),
          border: Border.all(color: selected ? VColors.borderHeavy : VColors.borderLight, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: VType.callout(
                  color: selected ? VColors.textPrimary : VColors.textSecondary,
                  weight: selected ? FontWeight.w600 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

/// Recessed capsule search field.
class VSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final double height;
  const VSearchField({super.key, this.controller, required this.hint, this.onChanged, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
      decoration: BoxDecoration(color: VColors.fillRecessed, borderRadius: BorderRadius.circular(VRadius.full)),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 17, color: VColors.textTertiary),
          const SizedBox(width: VSpace.xs),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: VColors.textPrimary,
              style: VType.callout(weight: FontWeight.w400),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: VType.callout(color: VColors.textTertiary, weight: FontWeight.w400),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped list container (account/settings rows).
class VListGroup extends StatelessWidget {
  final List<Widget> children;
  const VListGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: VColors.fillCell, borderRadius: BorderRadius.circular(VRadius.md)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: VSpace.md, color: VColors.borderLight),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// List row: leading, title, subtitle, trailing / chevron.
class VListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? trailingText;
  final bool chevron;
  final bool selected;
  final VoidCallback? onTap;
  final int subtitleLines;
  /// null: the title wraps in full (model names, v8.3 D44).
  final int? titleLines;

  const VListRow({
    this.titleLines = 1,
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.trailingText,
    this.chevron = false,
    this.selected = false,
    this.onTap,
    this.subtitleLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? VColors.overlayLight : Colors.transparent,
        borderRadius: BorderRadius.circular(selected ? VRadius.md : 0),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: VSpace.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, maxLines: titleLines, overflow: titleLines == null ? null : TextOverflow.ellipsis, style: VType.body(weight: FontWeight.w500).copyWith(height: VType.normal)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, maxLines: subtitleLines, overflow: TextOverflow.ellipsis, style: VType.footnote()),
                ],
              ],
            ),
          ),
          if (trailingText != null) ...[
            const SizedBox(width: VSpace.xs),
            Text(trailingText!, style: VType.footnote(color: VColors.textTertiary)),
          ],
          if (trailing != null) ...[const SizedBox(width: VSpace.xs), trailing!],
          if (chevron) ...[
            const SizedBox(width: VSpace.xxs),
            const Icon(Icons.chevron_right_rounded, size: 20, color: VColors.textTertiary),
          ],
        ],
      ),
    );
    return onTap == null ? body : VPress(onTap: onTap, child: body);
  }
}

/// Sidebar menu item: icon in a circle + label; selected = lighter capsule.
class VSidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  const VSidebarItem({super.key, required this.icon, required this.label, this.selected = false, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VMotion.fast,
        // v8.3 (D44): full labels wrap instead of an ellipsis.
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: VSpace.xs, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? VColors.overlayLight : Colors.transparent,
          borderRadius: BorderRadius.circular(VRadius.full),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? VColors.fillActive : VColors.fillCell),
              child: Icon(icon, size: 15, color: selected ? VColors.textPrimary : VColors.textSecondary),
            ),
            const SizedBox(width: VSpace.sm),
            Expanded(
              child: Text(label,
                  style: VType.callout(
                    color: selected ? VColors.textPrimary : VColors.textSecondary,
                    weight: selected ? FontWeight.w600 : FontWeight.w500,
                  )),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Provider-colour disc. v8.3 (D44): no initials ("G3", "GN" read as
/// mangled abbreviations); the full name sits beside it.
class VAvatar extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  const VAvatar({super.key, required this.label, required this.color, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// Media tile: rounded image, title and subtitle beneath (album grid).
class VTile extends StatelessWidget {
  final Widget media;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double aspect;
  final bool selected;
  const VTile({super.key, required this.media, required this.title, this.subtitle, this.onTap, this.aspect = 1, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? VColors.overlayLight : Colors.transparent,
          borderRadius: BorderRadius.circular(VRadius.md + 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: aspect,
              child: ClipRRect(borderRadius: BorderRadius.circular(VRadius.md), child: media),
            ),
            const SizedBox(height: 6),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w600)),
            if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.caption()),
          ],
        ),
      ),
    );
  }
}

/// Kit toggle: accent blue track when on.
class VToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const VToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: VMotion.fast,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? VColors.accentBlue : VColors.overlayDark,
          borderRadius: BorderRadius.circular(VRadius.full),
        ),
        child: AnimatedAlign(
          duration: VMotion.fast,
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: VShadow.subtle),
          ),
        ),
      ),
    );
  }
}

/// visionOS window bar: dot + grabber capsule beneath a window.
class VWindowBar extends StatelessWidget {
  const VWindowBar({super.key});
  @override
  // v9.1.4 (playtest #13): no dot-and-bar under windows on a phone.
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A bounded glass window with a visionOS header: leading circle, title, trailing circles.
class VWindow extends StatelessWidget {
  final String? title;
  final bool largeTitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget child;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry contentPadding;
  final VMaterial material;
  final bool centerTitle;
  final bool windowBar;

  const VWindow({
    super.key,
    this.title,
    this.largeTitle = false,
    this.leading,
    this.actions = const [],
    required this.child,
    this.maxWidth = 420,
    this.maxHeight,
    this.contentPadding = const EdgeInsets.fromLTRB(VSpace.md, 0, VSpace.md, VSpace.md),
    this.material = VMaterial.modal,
    this.centerTitle = false,
    this.windowBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final header = (title != null || leading != null || actions.isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.sm, VSpace.sm, VSpace.xs),
            child: SizedBox(
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (title != null)
                    Positioned.fill(
                      left: centerTitle ? 48 : (leading != null ? 48 : VSpace.xxs),
                      right: centerTitle ? 48 : (actions.length * 42.0),
                      child: Align(
                        alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: largeTitle ? VType.title() : VType.headline(),
                        ),
                      ),
                    ),
                  if (leading != null) Align(alignment: Alignment.centerLeft, child: leading!),
                  if (actions.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        for (int i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          actions[i],
                        ],
                      ]),
                    ),
                ],
              ),
            ),
          )
        : const SizedBox(height: VSpace.md);

    final window = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight ?? double.infinity),
        child: VGlass(
        material: material,
        radius: VRadius.xl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Flexible(child: Padding(padding: contentPadding, child: child)),
          ],
        ),
      ),
    );
    if (!windowBar) return window;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: window),
      const SizedBox(height: VSpace.sm),
      const VWindowBar(),
    ]);
  }
}

/// One button of a [VAlert].
class VAlertChoice {
  final String label;
  final bool destructive;
  const VAlertChoice(this.label, {this.destructive = false});
}

/// Alert (map row 22, Prime Video visionOS 130:75006): a centred glass card,
/// 320 wide, radius 32: an icon in a white 56 circle, a bold title, one line,
/// a hairline, then the actions stacked as plain 52-high text rows.
class VAlert extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? message;
  final List<VAlertChoice> actions;
  final ValueChanged<int> onSelect;
  final int messageLines;
  const VAlert({super.key, this.icon, required this.title, this.message, required this.actions, required this.onSelect, this.messageLines = 2});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: VFrost.blur, sigmaY: VFrost.blur),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null) ...[
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: Icon(icon, size: 30, color: const Color(0xFF3A3A3C)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(title, textAlign: TextAlign.center, style: VType.headline(color: Colors.white)),
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(message!, textAlign: TextAlign.center, maxLines: messageLines, overflow: TextOverflow.ellipsis,
                        style: VType.callout(color: Colors.white.withValues(alpha: 0.8), weight: FontWeight.w400)),
                  ),
                const SizedBox(height: 18),
                Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 20), color: const Color(0x33FFFFFF)),
                const SizedBox(height: 4),
                for (int i = 0; i < actions.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: VPress(
                      onTap: () => onSelect(i),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        child: Text(
                          actions[i].label,
                          style: VType.body(
                            weight: FontWeight.w600,
                            color: actions[i].destructive ? const Color(0xFFFF6961) : Colors.white,
                          ).copyWith(height: VType.normal),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a centred [VAlert] and returns the index of the chosen action, or
/// null when dismissed (tap outside or Escape).
Future<int?> showVAlert(
  BuildContext context, {
  IconData? icon,
  required String title,
  String? message,
  required List<VAlertChoice> actions,
  int messageLines = 2,
}) =>
    showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
      pageBuilder: (ctx, _, __) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: VAlert(icon: icon, title: title, message: message, actions: actions, messageLines: messageLines, onSelect: (i) => Navigator.of(ctx).pop(i)),
          ),
        ),
      ),
    );

/// Section title (window content headings: "My Albums", "Good morning").
class VSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final bool large;
  const VSectionTitle(this.text, {super.key, this.trailing, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: large ? VType.title() : VType.title2())),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Scroll view whose content dissolves at its edges (the faded-edge technique).
class VFadeScroll extends StatelessWidget {
  final Widget child;
  final double fade;
  final EdgeInsetsGeometry padding;
  final Axis axis;
  const VFadeScroll({super.key, required this.child, this.fade = 18, this.padding = EdgeInsets.zero, this.axis = Axis.vertical});

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      scrollDirection: axis,
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: child,
    );
    if (axis == Axis.horizontal) {
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          final f = (fade / (rect.width <= 0 ? 1 : rect.width)).clamp(0.0, 0.3);
          return LinearGradient(
            colors: const [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)],
            stops: [0, f, 1 - f, 1],
          ).createShader(rect);
        },
        child: scroll,
      );
    }
    return EdgeFade(fadeHeight: fade, child: scroll);
  }
}

/// One row of a [GlassMenu].
class GlassMenuRow {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback? onTap;
  /// A switch row (Incognito) vs a row that opens something (Account).
  final bool toggle;
  const GlassMenuRow({required this.icon, required this.label, this.on = false, this.onTap, this.toggle = true});
}

/// VisionOS Autolayout Menu (Figma 4CLz2H5l84ILrVUyskOnAS 1:3), built at its
/// own Figma geometry and scaled as one unit (v8.4): width 240, padding 16,
/// gap 4, rows 208 x 40 (icon wrapper p8 around a 24 icon, gap 16, Inter
/// Medium 16 white; inactive rows at 60 %), radius 24, 1 px white border,
/// backdrop blur 40, gradient fill rgba(79,79,79,.1) / white .1 at 127 deg.
/// The active row: gradient white .16 -> 0 (94.5 deg), icon disc white .3.
/// [scale] defaults to screen width / 637 (the Figma frame width), so the
/// menu covers the same 37.7 % of the screen width as in the frame.
class GlassMenu extends StatelessWidget {
  final List<GlassMenuRow> rows;
  /// Width in Figma px (240 in the frame).
  final double width;
  final double? scale;
  const GlassMenu({super.key, required this.rows, this.width = 240, this.scale});

  static const double frameWidth = 637;
  static double scaleFor(BuildContext context) => MediaQuery.sizeOf(context).width / frameWidth;
  static double heightFor(int n) => 32 + n * 40 + (n > 0 ? (n - 1) * 4 : 0);

  @override
  Widget build(BuildContext context) {
    final k = scale ?? scaleFor(context);
    final h = heightFor(rows.length);
    return SizedBox(
      width: width * k,
      height: h * k,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: width,
          height: h,
          child: SuspendedFrost(child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: VFrost.blur * k, sigmaY: VFrost.blur * k),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: VFrost.tint, // v9.1.1: the one glass recipe
                ),
                // The stroke and its shadow live in the foreground. Inside
                // `decoration` the border was painted under the very ClipRRect
                // that clips this box, so it was shaved off the leading edge
                // and the card stopped reading as a container at all.
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  // v9.1: no outline (suspended frost).
                  boxShadow: [
                    ...VFrost.shadow,
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      _row(rows[i]),
                    ],
                  ],
                ),
              ),
            ),
          )),
        ),
      ),
    );
  }

  Widget _row(GlassMenuRow r) {
    // Off rows used to drop to 0.3 / 0.6, which reads as broken rather than
    // inactive once the menu sits over a bright wallpaper: the label simply
    // disappeared. Inactive is now clearly readable, off is clearly muted.
    final op = r.on ? 1.0 : (r.onTap == null ? 0.45 : 0.82);
    return Semantics(
      button: true,
      toggled: r.toggle ? r.on : null,
      label: r.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: r.onTap,
        child: AnimatedContainer(
          duration: VMotion.fast,
          width: 208,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(48),
            gradient: r.on ? const LinearGradient(colors: [Color(0x29FFFFFF), Color(0x00FFFFFF)], stops: [0.005, 1.4]) : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: VMotion.fast,
                width: 40,
                height: 40,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(61), color: r.on ? const Color(0x4DFFFFFF) : Colors.transparent),
                child: Icon(r.icon, size: 24, color: Colors.white.withValues(alpha: op)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  r.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: op)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// v8.7: temporary UI (Settings, context menus, popups) looks suspended in
/// mid-air: no outline, the frosted panel dissolves at its perimeter.
class SuspendedFrost extends StatelessWidget {
  final Widget child;
  final double edge;
  const SuspendedFrost({super.key, required this.child, this.edge = 0.06});
  @override
  Widget build(BuildContext context) {
    // v9.1.1: a ShaderMask over a BackdropFilter kills the blur on web, so
    // the edge now fades through the soft VFrost shadow instead.
    return child;
  }
}

/// v8.7 ghost menu: a floating vertical picker with no outlines. The centred
/// item is sharp; items above and below blur and fade with distance. The
/// frosted backing dissolves at its edges (suspended mid-air).
class GhostMenu extends StatefulWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final double width;
  final double itemExtent;
  final int visible;
  final List<IconData>? icons;
  const GhostMenu({super.key, required this.items, required this.selected, required this.onSelected,
      this.width = 120, this.itemExtent = 36, this.visible = 5, this.icons});
  @override
  State<GhostMenu> createState() => _GhostMenuState();
}

class _GhostMenuState extends State<GhostMenu> {
  late final FixedExtentScrollController _c = FixedExtentScrollController(initialItem: widget.selected);
  @override
  void didUpdateWidget(covariant GhostMenu old) {
    super.didUpdateWidget(old);
    if (_c.hasClients && widget.selected != _c.selectedItem && widget.selected < widget.items.length) {
      _c.animateToItem(widget.selected, duration: VMotion.base, curve: Curves.easeOutCubic);
    }
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final h = widget.itemExtent * widget.visible;
    return SuspendedFrost(
      edge: 0.18,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: VFrost.blur, sigmaY: VFrost.blur),
          child: Container(
            width: widget.width,
            height: h,
            color: VFrost.tint,
            child: ListWheelScrollView.useDelegate(
              controller: _c,
              itemExtent: widget.itemExtent,
              diameterRatio: 3,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: widget.onSelected,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.items.length,
                builder: (context, i) => AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final pos = _c.hasClients && _c.position.hasContentDimensions
                        ? _c.offset / widget.itemExtent
                        : widget.selected.toDouble();
                    final d = (i - pos).abs();
                    final sigma = (d * 2.2).clamp(0.0, 6.0);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _c.animateToItem(i, duration: VMotion.base, curve: Curves.easeOutCubic),
                      child: Opacity(
                        opacity: (1 - d * 0.32).clamp(0.08, 1.0),
                        child: ImageFiltered(
                          enabled: sigma > 0.05,
                          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                          child: Center(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (widget.icons != null && i < widget.icons!.length) ...[
                                Icon(widget.icons![i], size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(widget.items[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: d < 0.5 ? FontWeight.w600 : FontWeight.w400)),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
