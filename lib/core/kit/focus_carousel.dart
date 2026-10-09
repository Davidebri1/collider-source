import 'package:flutter/material.dart';

import '../theme/edge_fade.dart';
import 'collider_kit.dart';

/// A vertical reel: rows scroll through a focus band and give ground as they
/// leave it, dissolving at the panel edges instead of ending on a cut line.
///
/// Why this exists
/// ---------------
/// The wechat vision os window exports (Window.pdf x5) are a stack of 300x88
/// glass rows at a 6px pitch inside a 20-radius panel. That stack is not a
/// plain list - it reads as a reel: one row carries the eye, its neighbours
/// sit quieter, and the panel edge takes the rest. [EdgeFade] supplied the
/// dissolve; the distance falloff supplies the focus. Together they are what
/// makes the same component work inset into a small summoned panel (Jarvis
/// summons, Themes menu) as well as in a full-height window.
///
/// Used by: ticker summaries, Themes / Premium Themes menus, summoned
/// panels, bottom / middle / top panes, temporary selection overlays.
///
/// The widget is deliberately dumb about *what* a row is. It lays out, fades
/// and scales; the caller supplies the row and the selection.
class FocusCarousel extends StatefulWidget {
  const FocusCarousel({
    super.key,
    required this.itemCount,
    required this.itemExtent,
    required this.itemBuilder,
    this.selectedIndex,
    this.onSelect,
    this.focusAlignment = 0.5,
    this.fade,
    this.padding = EdgeInsets.zero,
    this.minScale = Kit.focusMinScale,
    this.minOpacity = Kit.focusMinOpacity,
    this.reach = Kit.focusReach,
    this.snap = true,
    this.physics,
  });

  final int itemCount;

  /// Fixed pitch of one slot, item body plus gap. A reel has no variable
  /// rhythm - if rows differ in height the falloff stops reading as one scale.
  final double itemExtent;

  final Widget Function(BuildContext context, int index, bool selected) itemBuilder;

  final int? selectedIndex;
  final ValueChanged<int>? onSelect;

  /// Where in the viewport the focus band sits. 0.5 is the reel default:
  /// focused row dead centre, falloff symmetric above and below.
  final double focusAlignment;

  /// Dissolve height at each end. Null uses [Kit.focusFade].
  final double? fade;

  final EdgeInsetsGeometry padding;

  /// How far a row shrinks once it is fully out of the band.
  final double minScale;

  /// How far a row dims once it is fully out of the band.
  final double minOpacity;

  /// Distance from the band, in slots, at which a row is fully out.
  final double reach;

  /// Settle onto slot boundaries, so the reel stops like a slot machine.
  final bool snap;

  final ScrollPhysics? physics;

  @override
  State<FocusCarousel> createState() => _FocusCarouselState();
}

class _FocusCarouselState extends State<FocusCarousel> {
  late final ScrollController _c = ScrollController();

  @override
  void initState() {
    super.initState();
    _c.addListener(_onScroll);
  }

  @override
  void dispose() {
    _c.removeListener(_onScroll);
    _c.dispose();
    super.dispose();
  }

  void _onScroll() => setState(() {});

  /// Bring a slot into the band. Called when the host changes selection, so a
  /// row chosen from elsewhere in the app lands centred rather than half off.
  void scrollTo(int index) {
    if (!_c.hasClients) return;
    final target = _bandOffset(index);
    if ((target - _c.offset).abs() < 0.5) return;
    _c.animateTo(
      target,
      duration: Kit.motionBase,
      curve: Kit.motionEase,
    );
  }

  double _viewport() => _c.hasClients ? _c.position.viewportDimension : 0;

  /// Scroll offset that puts [index] on the focus line.
  double _bandOffset(int index) {
    final v = _viewport();
    if (v <= 0) return 0;
    final focusY = v * widget.focusAlignment;
    final rowCentreInContent =
        widget.padding.vertical * 0.5 + index * widget.itemExtent + widget.itemExtent / 2;
    return (rowCentreInContent - focusY).clamp(
      0.0,
      _c.hasClients ? _c.position.maxScrollExtent : double.infinity,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return const SizedBox.shrink();

    final v = _viewport();
    final focusY = v * widget.focusAlignment;
    // Distance is measured in slots, so the falloff is identical whether the
    // host is a 300pt summoned panel or a full-height window.
    double falloff(double rowCentre) {
      if (v <= 0) return 0;
      final slots = ((rowCentre - focusY).abs() / widget.itemExtent) / widget.reach;
      return slots.clamp(0.0, 1.0);
    }

    final fade = widget.fade ?? Kit.focusFade;

    final list = ListView.builder(
      controller: _c,
      padding: widget.padding,
      itemCount: widget.itemCount,
      itemExtent: widget.itemExtent,
      physics: widget.physics ?? const BouncingScrollPhysics(),
      itemBuilder: (context, i) {
        final rowCentre = widget.padding.vertical * 0.5 +
            i * widget.itemExtent +
            widget.itemExtent / 2 -
            (_c.hasClients ? _c.offset : 0);
        final t = falloff(rowCentre);
        final selected = widget.selectedIndex == i;
        return Transform.scale(
          scale: 1 - (1 - widget.minScale) * t,
          alignment: Alignment.center,
          child: Opacity(
            // A selected row stays fully lit wherever it is - selection
            // outranks distance, otherwise choosing a row dims the thing
            // you just chose.
            opacity: selected ? 1.0 : 1 - (1 - widget.minOpacity) * t,
            child: widget.itemBuilder(context, i, selected),
          ),
        );
      },
    );

    // The fade is the outer half of the effect and stays separate: masking
    // alone gives the dissolve, scaling alone gives the reel, and the two
    // read as one thing only when both are on the same subtree.
    Widget reel = EdgeFade(fadeHeight: fade, child: list);

    if (widget.snap) {
      final slot = widget.itemExtent;
      reel = NotificationListener<ScrollEndNotification>(
        onNotification: (n) {
          if (n.metrics.axis != Axis.vertical) return false;
          _snapTo(_c.hasClients ? _c.position : null, slot);
          return false;
        },
        child: reel,
      );
    }
    return reel;
  }

  bool _settling = false;

  /// Move to the nearest slot once the fling has finished.
  void _snapTo(ScrollPosition? position, double slot) {
    if (_settling || position == null || slot <= 0) return;
    final target = (position.pixels / slot).roundToDouble() * slot;
    if ((target - position.pixels).abs() < 0.5) return;
    _settling = true;
    _c
        .animateTo(
          target.clamp(position.minScrollExtent, position.maxScrollExtent),
          duration: Kit.motionFast,
          curve: Kit.motionEase,
        )
        .whenComplete(() => _settling = false);
  }
}
