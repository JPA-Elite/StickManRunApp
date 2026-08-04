import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single finished run's stats, persisted so scores survive restarts.
@immutable
class ScoreRecord {
  final int score;
  final int coins;
  final double distanceMeters;
  final int levelIndex;
  final DateTime timestamp;

  const ScoreRecord({
    required this.score,
    required this.coins,
    required this.distanceMeters,
    required this.levelIndex,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'coins': coins,
        'distanceMeters': distanceMeters,
        'levelIndex': levelIndex,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory ScoreRecord.fromJson(Map<String, dynamic> json) => ScoreRecord(
        score: json['score'] as int,
        coins: json['coins'] as int,
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        levelIndex: json['levelIndex'] as int,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as num).toInt(),
        ),
      );
}

/// Singleton controller that persists the last [maxRecords] finished runs to
/// SharedPreferences and exposes best-score helpers.
class ScoreHistoryController extends ChangeNotifier {
  ScoreHistoryController._();

  static final ScoreHistoryController instance = ScoreHistoryController._();

  static const String _keyRecords = 'score_history_v1';
  static const int maxRecords = 20;

  List<ScoreRecord> _records = [];
  List<ScoreRecord> get records => List.unmodifiable(_records);

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Highest score across all recorded runs (0 when empty).
  int get bestScore => _records.isEmpty
      ? 0
      : _records.map((r) => r.score).reduce((a, b) => a > b ? a : b);

  /// Highest score for a given level (0 when none).
  int bestForLevel(int levelIndex) {
    var best = 0;
    for (final r in _records) {
      if (r.levelIndex == levelIndex && r.score > best) best = r.score;
    }
    return best;
  }

  /// Loads persisted history (idempotent). Returns immediately if already loaded.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRecords);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => ScoreRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        _records = List.of(list);
      } catch (_) {
        _records = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyRecords,
      jsonEncode(_records.map((r) => r.toJson()).toList()),
    );
  }

  /// Appends a finished run at the front, caps at [maxRecords], persists.
  Future<void> add(ScoreRecord record) async {
    _records.insert(0, record);
    if (_records.length > maxRecords) {
      _records = _records.sublist(0, maxRecords);
    }
    await _save();
    notifyListeners();
  }

  /// Empties all history and persists.
  Future<void> clear() async {
    _records = [];
    await _save();
    notifyListeners();
  }
}