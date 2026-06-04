import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Loads a Quill [Document] from stored content.
///
///// Stored formats supported:
/// 1) JSON ops list: `[{"insert":"..."}, ...]` (flutter_quill v9-friendly)
/// 2) JSON delta object: `{"ops":[{"insert":"..."}, ...]}`
/// 3) Legacy plain text stored in the same field
Document quillDocumentFromContent(String contentDeltaJsonOrPlainText) {
  final raw = contentDeltaJsonOrPlainText.trim();
  if (raw.isEmpty) {
    return Document.fromJson([
      {'insert': '\n'}
    ]);
  }

  try {
    final decoded = jsonDecode(raw);

    // Case 1: ops list
    if (decoded is List) {
      return Document.fromJson(decoded.cast<dynamic>());
    }

    // Case 2: {'ops':[...]}
    if (decoded is Map<String, dynamic>) {
      final ops = decoded['ops'];
      if (ops is List) {
        return Document.fromJson(ops.cast<dynamic>());
      }
    }
  } catch (_) {
    // fall through to legacy plain-text behavior
  }

  // Legacy: plain text stored in contentDeltaJson.
  final plain = raw;
  return Document.fromJson([
    {'insert': '$plain\n'}
  ]);
}

/// Converts a Quill document back into a JSON string.
/// We try to store the simplest representation first: ops list.
String quillDocumentToDeltaJsonString(Document document) {
  final deltaJson = document.toDelta().toJson();
  return jsonEncode(deltaJson);
}

String quillDeltaContentToPlainText(String contentDeltaJsonOrPlainText) {
  final doc = quillDocumentFromContent(contentDeltaJsonOrPlainText);
  return doc.toPlainText().trim();
}

/// Creates a delta JSON ops-list string from plain text.
String plainTextToDeltaJsonString(String text) {
  final t = text.trim();
  if (t.isEmpty) {
    return jsonEncode([
      {'insert': '\n'}
    ]);
  }

  return jsonEncode([
    {'insert': '$t\n'}
  ]);
}
