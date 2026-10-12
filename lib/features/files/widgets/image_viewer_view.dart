// In-app image viewer: the picture fitted to the window, pinch and double-tap
// zoom, and the file's real name / size / type under it.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/files/file_store.dart';
import '../../../core/vision/vision_kit.dart';

class ImageViewerView extends StatefulWidget {
  final StoredFile file;
  final Uint8List bytes;

  const ImageViewerView({super.key, required this.file, required this.bytes});

  @override
  State<ImageViewerView> createState() => _ImageViewerViewState();
}

class _ImageViewerViewState extends State<ImageViewerView> {
  final TransformationController _t = TransformationController();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// Double-tap zooms in; tapping again returns to fit.
  void _onDoubleTap() {
    final current = _t.value.getMaxScaleOnAxis();
    if (current > 1.05) {
      _t.value = Matrix4.identity();
    } else {
      _t.value = Matrix4.identity()..scale(2.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final close = VCircleButton(
      icon: Icons.close_rounded,
      tooltip: 'Close',
      floating: true,
      onTap: () => Navigator.of(context).pop(),
    );
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(VSpace.md, 40, VSpace.md, 96),
          child: VWindow(
            title: f.name,
            centerTitle: true,
            maxWidth: VOverlay.toolWidth(context),
            maxHeight: VOverlay.toolMaxHeight(context),
            leading: close,
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onDoubleTap: _onDoubleTap,
                    child: InteractiveViewer(
                      transformationController: _t,
                      minScale: 1,
                      maxScale: 8,
                      child: Center(
                        child: Image.memory(
                          widget.bytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const _Broken(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: VSpace.xs),
                Text(
                  '${FileStore.sizeLabel(f.sizeBytes)}  ·  ${FileStore.mimeFor(f.name)}',
                  style: VType.caption(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(VSpace.xl),
        child: Icon(Icons.broken_image_outlined, size: 44, color: VColors.textTertiary),
      );
}