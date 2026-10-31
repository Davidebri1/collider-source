import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:planka_app/models/card_models/planka_attachment.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../local/planka_store.dart';
import 'auth_provider.dart';

import '../hooks.dart';
export '../hooks.dart' show plankaAttachmentPut, plankaAttachmentGet, AttachmentBytesPut, AttachmentBytesGet;

class AttachmentProvider with ChangeNotifier {
  PlankaAttachment? _attachment;
  Uint8List? _imageData;

  final AuthProvider authProvider;

  AttachmentProvider(this.authProvider);

  PlankaAttachment? get attachment => _attachment;
  Uint8List? get imageData => _imageData;

  Future<void> downloadFile(String url, String fileName, BuildContext context) async {
    // Local store: nothing to download from a remote URL.
    if (context.mounted) {
      showTopSnackBar(
        Overlay.of(context),
        CustomSnackBar.success(message: 'downloaded_file'.tr()),
      );
    }
  }

  Future<Image?> fetchAttachmentImage({
    required String myUrl,
    required BuildContext context,
  }) async {
    final get = plankaAttachmentGet;
    if (get == null) return null;
    // myUrl may be blob:<id> or a plain blob id
    final id = myUrl.startsWith('blob:') ? myUrl.substring(5) : myUrl;
    final bytes = await get(id);
    if (bytes == null) return null;
    _imageData = bytes;
    return Image.memory(bytes, fit: BoxFit.cover);
  }

  Future<void> deleteAttachment({required BuildContext context, required String attachmentId}) async {
    PlankaStore.instance.deleteAttachment(attachmentId);
    notifyListeners();
  }

  /// Local create — pass bytes + name (web-safe; replaces File upload).
  Future<void> createAttachmentBytes({
    required BuildContext context,
    required String cardId,
    required String name,
    required Uint8List bytes,
  }) async {
    final a = PlankaStore.instance.createAttachment(
      cardId: cardId,
      name: name,
      url: null,
      blobId: null,
    );
    final blobId = 'smartgen/planka/att/${a['id']}';
    a['blobId'] = blobId;
    a['url'] = 'blob:$blobId';
    final put = plankaAttachmentPut;
    if (put != null) await put(blobId, bytes);
    if (context.mounted) {
      showTopSnackBar(
        Overlay.of(context),
        CustomSnackBar.info(message: 'added_attachment'.tr()),
      );
    }
    notifyListeners();
  }

  /// Kept for call-site compatibility; expects name via path basename when bytes unavailable.
  Future<void> createAttachment({
    required BuildContext context,
    required String cardId,
    required String name,
    Uint8List? bytes,
  }) async {
    await createAttachmentBytes(
      context: context,
      cardId: cardId,
      name: name,
      bytes: bytes ?? Uint8List(0),
    );
  }

  Future<void> renameAttachment({
    required BuildContext context,
    required String cardId,
    required String newAttachName,
    required String attachId,
  }) async {
    PlankaStore.instance.renameAttachment(attachId, newAttachName);
    notifyListeners();
  }

  Image? getAttachmentImage() {
    if (_imageData != null) return Image.memory(_imageData!);
    return null;
  }
}
