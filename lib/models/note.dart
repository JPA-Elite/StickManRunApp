import 'dart:convert';

class NoteAttachment {
  final String name;
  final String type;
  final String base64Data;

  const NoteAttachment({
    required this.name,
    required this.type,
    required this.base64Data,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'base64Data': base64Data,
      };

  factory NoteAttachment.fromJson(Map<String, dynamic> json) {
    return NoteAttachment(
      name: json['name'] as String,
      type: (json['type'] as String?) ?? 'application/octet-stream',
      base64Data: json['base64Data'] as String,
    );
  }
}

/// We store rich content as a Quill delta (JSON-serializable Map).
/// This keeps edit/view consistent across the app.
class Note {
  final String id;
  final String title;
  final String contentDeltaJson; // stringified JSON (safer for storage)
  final DateTime createdAt;
  final DateTime updatedAt;

  final bool isLocked;
  final String? pin;
  final String? scheduledDeleteIso;

  final List<NoteAttachment> attachments;

  const Note({
    required this.id,
    required this.title,
    required this.contentDeltaJson,
    required this.createdAt,
    required this.updatedAt,
    required this.attachments,
    this.isLocked = false,
    this.pin,
    this.scheduledDeleteIso,
  });

  bool get hasScheduledDelete =>
      scheduledDeleteIso != null && scheduledDeleteIso!.isNotEmpty;

  DateTime? get scheduledDelete {
    if (!hasScheduledDelete) return null;
    return DateTime.tryParse(scheduledDeleteIso!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'contentDeltaJson': contentDeltaJson,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isLocked': isLocked,
        'pin': pin,
        'scheduledDeleteIso': scheduledDeleteIso,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      contentDeltaJson: (json['contentDeltaJson'] as String?) ?? '{"ops": []}',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isLocked: (json['isLocked'] as bool?) ?? false,
      pin: json['pin'] as String?,
      scheduledDeleteIso: json['scheduledDeleteIso'] as String?,
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map((e) => NoteAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Useful when we need a valid empty delta string.
  static String emptyDeltaJson() => jsonEncode({'ops': []});
}
