import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

class NotesRepository {
  static const String _notesKey = 'notes';
  static const String _notesFileName = 'notes.json';

  final SharedPreferences prefs;

  const NotesRepository({required this.prefs});

  Future<String?> _readRaw() async {
    if (kIsWeb) {
      final raw = prefs.getString(_notesKey);
      return raw;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_notesFileName');

    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<void> _writeRaw(String raw) async {
    if (kIsWeb) {
      await prefs.setString(_notesKey, raw);
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_notesFileName');
    await file.writeAsString(raw, flush: true);
  }

  Future<List<Note>> getNotes() async {
    final raw = await _readRaw();
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
    await _writeRaw(encoded);
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

    var changed = false;
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
    if (kIsWeb) {
      await prefs.remove(_notesKey);
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_notesFileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> exportNotesJson() async {
    final notes = await getNotes();
    return jsonEncode(notes.map((n) => n.toJson()).toList());
  }
}
