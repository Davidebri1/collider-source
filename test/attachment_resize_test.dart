import 'dart:typed_data';

import 'package:collider_flutter/features/prompt/attached_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

void main() {
  test('a large image is sent as a smaller copy and the original bytes stay', () {
    final img = im.Image(width: 900, height: 700);
    for (var y = 0; y < img.height; y++) {
      for (var x = 0; x < img.width; x++) {
        img.setPixelRgb(x, y, (x * 17 + y) & 255, 40, (y * 13) & 255);
      }
    }
    final original = Uint8List.fromList(im.encodeJpg(img, quality: 95));
    final before = original.length;
    final sent = resizedImageCopy(original, maxBytes: 20000);
    expect(sent, isNotNull);
    expect(sent!.length, lessThanOrEqualTo(20000));
    expect(sent.length, lessThan(before));
    expect(original.length, before);
    final classified = classifyAttachment('scan.jpg', original);
    // The production cap is 4 MB. This file is under it, so it is sent as-is.
    expect(classified.disposition, AttachmentDisposition.image);
    final padded = Uint8List.fromList([...original, ...Uint8List(kAttachedImageMaxBytes)]);
    final paddedLen = padded.length;
    final hugeCap = classifyAttachment('scan.jpg', padded);
    expect(hugeCap.disposition, AttachmentDisposition.imageResized);
    expect(hugeCap.text, contains('saved file was not changed'));
    expect(padded.length, paddedLen);
    expect(hugeCap.imageUri, isNotNull);
  });

  test('unknown binary chip text does not claim the contents were sent', () {
    expect(attachmentChipLabel('clip.bin'), 'clip.bin · name and size only');
    expect(attachmentChipLabel('page.pdf'), 'page.pdf');
  });
}
