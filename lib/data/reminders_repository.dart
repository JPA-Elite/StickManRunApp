import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';

class RemindersRepository {
  static const String _remindersKey = 'reminders';
  static const String _remindersFileName = 'reminders.json';

  final SharedPreferences prefs;

  const RemindersRepository({required this.prefs});

  Future<String?> _readRaw() async {
    if (kIsWeb) {
      return prefs.getString(_remindersKey);
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_remindersFileName');
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<void> _writeRaw(String raw) async {
    if (kIsWeb) {
      await prefs.setString(_remindersKey, raw);
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_remindersFileName');
    await file.writeAsString(raw, flush: true);
  }

  Future<List<Reminder>> getReminders() async {
    final raw = await _readRaw();
    if (raw == null || raw.isEmpty) return const [];

    return Reminder.listFromJsonString(raw);
  }

  Future<void> saveReminders(List<Reminder> reminders) async {
    final encoded = Reminder.listToJsonString(reminders);
    await _writeRaw(encoded);
  }

  Future<void> addReminder(Reminder reminder) async {
    final reminders = await getReminders();
    final updated = [reminder, ...reminders];
    await saveReminders(updated);
  }

  Future<void> deleteReminder(String reminderId) async {
    final reminders = await getReminders();
    final next =
        reminders.where((r) => r.id != reminderId).toList(growable: false);
    await saveReminders(next);
  }

  /// Removes reminders that are already in the past.
  /// Returns the number removed.
  Future<int> purgeExpiredReminders() async {
    final reminders = await getReminders();
    final now = DateTime.now();

    final kept = <Reminder>[];
    var removed = 0;

    for (final r in reminders) {
      if (r.scheduledAt.isBefore(now)) {
        removed++;
      } else {
        kept.add(r);
      }
    }

    if (removed <= 0) return 0;
    await saveReminders(kept);
    return removed;
  }
}
