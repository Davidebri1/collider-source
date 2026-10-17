// In-app PDF reader: the real pages (text pulled out of the file's content
// streams) laid out at the document's real page geometry, with page
// navigation. This is a reader, not a renderer — it shows what the PDF says.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/files/file_store.dart';
import '../../../core/files/pdf_probe.dart';
import '../../../core/vision/vision_kit.dart';

class PdfViewerView extends StatefulWidget {
  final StoredFile file;
  final Uint8List bytes;

  const PdfViewerView({super.key, required this.file, required this.bytes});

  @override
  State<PdfViewerView> createState() => _PdfViewerViewState();
}

class _PdfViewerViewState extends State<PdfViewerView> {
  static const int _maxChars = 40000;

  PdfDoc? _doc;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    probePdf(widget.bytes).then((d) {
      if (mounted) setState(() => _doc = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final doc = _doc;
    final pages = doc?.pages ?? const <PdfPage>[];
    final index = _page.clamp(0, (pages.isEmpty ? 0 : pages.length - 1));
    final page = pages.isEmpty ? null : pages[index];

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
            actions: [
            ],
            // v9.1.4: pages turn with a horizontal swipe, not arrows.
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -250 && index < pages.length - 1) setState(() => _page = index + 1);
                if (v > 250 && index > 0) setState(() => _page = index - 1);
              },
              child: doc == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : pages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(VSpace.xl),
                          child: Text(
                            'No page text could be read from this PDF.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: VColors.textTertiary),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Sheet(page: page!, file: f)),
                          const SizedBox(height: VSpace.xs),
                          Row(
                            children: [
                              Text('Page ${index + 1} of ${pages.length}', style: VType.caption()),
                              const Spacer(),
                              Text(
                                page.aspect > 0
                                    ? '${page.width.round()} x ${page.height.round()} pt'
                                    : FileStore.sizeLabel(f.sizeBytes),
                                style: VType.caption(),
                              ),
                            ],
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One page drawn as a white sheet with the page's real aspect ratio.
class _Sheet extends StatelessWidget {
  final PdfPage page;
  final StoredFile file;

  const _Sheet({required this.page, required this.file});

  @override
  Widget build(BuildContext context) {
    final aspect = page.aspect > 0 ? page.aspect : 0.7727;
    return LayoutBuilder(
      builder: (context, box) {
        // Fit the sheet inside the window at the real page proportion.
        var w = box.maxWidth;
        var h = w / aspect;
        if (h > box.maxHeight) {
          h = box.maxHeight;
          w = h * aspect;
        }
        var text = page.lines.join('\n');
        if (text.length > _PdfViewerViewState._maxChars) {
          text = text.substring(0, _PdfViewerViewState._maxChars);
        }
        return Center(
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F5F2),
              borderRadius: BorderRadius.circular(VRadius.xs),
              boxShadow: VShadow.medium,
            ),
            clipBehavior: Clip.antiAlias,
            child: text.isEmpty
                ? Center(
                    child: Text(
                      'This page has no extractable text.',
                      style: VType.caption().copyWith(color: const Color(0xFF8A8A85)),
                    ),
                  )
                : EdgeFade(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: VSpace.md, vertical: VSpace.md),
                      child: SelectableText(
                        text,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          height: 1.5,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}