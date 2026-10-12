// The terminal state for a type Files has no viewer for. It is never a crash
// and never a dead end: it names the type, says why there is nothing to show,
// and offers the one thing that can still be done with the file.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/files/file_blobs.dart';
import '../../../core/files/file_store.dart';
import '../../../core/vision/vision_kit.dart';
import 'thumb_view.dart';

class UnsupportedView extends StatefulWidget {
  final StoredFile file;
  final Uint8List bytes;

  const UnsupportedView({super.key, required this.file, required this.bytes});

  @override
  State<UnsupportedView> createState() => _UnsupportedViewState();
}

class _UnsupportedViewState extends State<UnsupportedView> {
  bool _busy = false;

  Future<void> _openExternally() async {
    setState(() => _busy = true);
    final mime = FileStore.mimeFor(widget.file.name);
    final ok = await FileBlobs.openExternal(widget.file.name, widget.bytes, mime);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      await showVAlert(
        context,
        icon: Icons.error_outline_rounded,
        title: 'Could not open ${widget.file.name}',
        actions: const [VAlertChoice('OK')],
      );
    }
  }

  String get _why {
    final ext = FileStore.extOf(widget.file.name);
    final label = ext.isEmpty ? 'This file' : '.$ext files';
    return '$label have no preview in Collider. You can still open it with another app.';
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 132,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(VRadius.card),
                    border: Border.all(color: VColors.borderLight, width: 0.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FilePlate(file: f),
                ),
                const SizedBox(height: VSpace.lg),
                Text(f.name, textAlign: TextAlign.center, style: VType.title2()),
                const SizedBox(height: VSpace.xs),
                Text(
                  '${FileStore.sizeLabel(f.sizeBytes)}  ·  ${FileStore.mimeFor(f.name)}',
                  textAlign: TextAlign.center,
                  style: VType.caption(),
                ),
                const SizedBox(height: VSpace.md),
                Text(
                  _why,
                  textAlign: TextAlign.center,
                  style: VType.footnote(),
                ),
                const SizedBox(height: VSpace.xl),
                VButton(
                  label: 'Open with another app',
                  icon: Icons.open_in_new_rounded,
                  variant: VButtonVariant.primary,
                  expand: true,
                  onTap: _busy ? null : _openExternally,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}