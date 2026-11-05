import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// على الحاسوب: نافذة «حفظ باسم». يعيد false إذا ألغى المستخدم.
Future<bool> saveTextFile(String fileName, String content, {String mimeType = 'application/json'}) async {
  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: const [XTypeGroup(label: 'نسخة مُعين', extensions: ['json'])],
  );
  if (location == null) return false;
  final file = XFile.fromData(
    Uint8List.fromList(utf8.encode(content)),
    mimeType: mimeType,
    name: fileName,
  );
  await file.saveTo(location.path);
  return true;
}
