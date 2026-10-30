import 'package:file_picker/file_picker.dart';

/// Non-web: fall through to file_picker.
Future<FilePickerResult?> pickFilesWebFriendly({bool allowMultiple = true}) =>
    FilePicker.platform.pickFiles(allowMultiple: allowMultiple, withData: true);
