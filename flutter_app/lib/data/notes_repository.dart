import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

class NotesRepository {
  static const String _notesKey = 'notes';

  final SharedPreferences prefs;

  const NotesRepository({required this.prefs});

  Future<List<Note>> getNotes() async {
    final raw = prefs.getString(_notesKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Note.fromJson)
        .toList(growable: false);
  }

  Future<void> saveNotes(List<Note> notes) async {
    final encoded = jsonEncode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_notesKey, encoded);
  }

  Future<void> addNote(Note note) async {
    final notes = await getNotes();
    final updated = [note, ...notes];
    await saveNotes(updated);
  }

  Future<void> updateNote(Note updatedNote) async {
    final notes = await getNotes();
    final idx = notes.indexWhere((n) => n.id == updatedNote.id);
    if (idx < 0) return;
    final next = List<Note>.from(notes);
    next[idx] = updatedNote;
    await saveNotes(next);
  }

  Future<void> deleteNote(String id) async {
    final notes = await getNotes();
    final next = notes.where((n) => n.id != id).toList(growable: false);
    await saveNotes(next);
  }

  Future<int> purgeExpiredScheduledDeletes() async {
    final notes = await getNotes();
    final now = DateTime.now();

    bool changed = false;
    final kept = <Note>[];
    for (final n in notes) {
      final scheduled = n.scheduledDelete;
      if (scheduled != null && scheduled.isBefore(now)) {
        changed = true;
        continue;
      }
      kept.add(n);
    }

    if (!changed) return 0;

    await saveNotes(kept);
    return notes.length - kept.length;
  }

  Future<void> clearAll() async {
    await prefs.remove(_notesKey);
  }

  Future<String> exportNotesJson() async {
    final notes = await getNotes();
    return jsonEncode(notes.map((n) => n.toJson()).toList());
  }
}
