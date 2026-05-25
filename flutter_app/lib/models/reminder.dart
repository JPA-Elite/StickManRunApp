import 'dart:convert';

class Reminder {
  final String id;
  final String title;
  final String message;
  final DateTime scheduledAt;
  final DateTime createdAt;

  const Reminder({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'scheduledAtIso': scheduledAt.toIso8601String(),
        'createdAtIso': createdAt.toIso8601String(),
      };

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      scheduledAt: DateTime.parse(json['scheduledAtIso'] as String),
      createdAt: DateTime.parse(json['createdAtIso'] as String),
    );
  }

  static List<Reminder> listFromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Reminder.fromJson)
        .toList(growable: false);
  }

  static String listToJsonString(List<Reminder> reminders) {
    return jsonEncode(reminders.map((r) => r.toJson()).toList());
  }
}
