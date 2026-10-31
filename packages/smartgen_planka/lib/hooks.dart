import 'dart:typed_data';

typedef PlankaGenieChat = Future<String> Function(List<Map<String, String>> messages);
PlankaGenieChat? plankaGenieChat;

typedef AttachmentBytesPut = Future<void> Function(String blobId, Uint8List bytes);
typedef AttachmentBytesGet = Future<Uint8List?> Function(String blobId);
AttachmentBytesPut? plankaAttachmentPut;
AttachmentBytesGet? plankaAttachmentGet;
