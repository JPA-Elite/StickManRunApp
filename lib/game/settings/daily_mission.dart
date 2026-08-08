import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'skill_controller.dart';

/// A single day's score-based mission.
@immutable
class DailyMission {
  final int targetScore;
  final int rewardCoins;
  final String description;

  const DailyMission({
    required this.targetScore,
    required this.rewardCoins,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'targetScore': targetScore,
        'rewardCoins': rewardCoins,
        'description': description,
      };

  factory DailyMission.fromJson(Map<String, dynamic> json) => DailyMission(
        targetScore: json['targetScore'] as int,
        rewardCoins: json['rewardCoins'] as int,
        description: json['description'] as String,
      );
}

/// Singleton controller that manages the daily mission: a single score-based
/// mission that resets each UTC day. Missions are randomly selected from a pool
/// and the reward is claimed manually (awarded to the skill wallet).
class DailyMissionController extends ChangeNotifier {
  DailyMissionController._();

  static final DailyMissionController instance = DailyMissionController._();

  static const String _keyMission = 'daily_mission_v1';
  static const String _keyMissionCompleted = 'daily_mission_completed_v1';
  static const String _keyMissionClaimed = 'daily_mission_claimed_v1';
  static const String _keyMissionDate = 'daily_mission_date_v1';

  /// Pool of possible missions. The day number (UTC) seeded into [Random]
  /// selects one deterministically each day.
  static const List<DailyMission> _missions = [
    DailyMission(targetScore: 10000, rewardCoins: 100, description: 'SCORE 10000+'),
    DailyMission(targetScore: 20000, rewardCoins: 300, description: 'SCORE 20000+'),
    DailyMission(targetScore: 30000, rewardCoins: 500, description: 'SCORE 30000+'),
    DailyMission(targetScore: 50000, rewardCoins: 750, description: 'SCORE 50000+'),
  ];

  DailyMission? _mission;
  DailyMission? get mission => _mission;

  /// Highest score seen today (used to track progress toward the target).
  int _bestScoreToday = 0;
  int get bestScoreToday => _bestScoreToday;

  bool _completed = false;
  bool get completed => _completed;

  bool _claimed = false;
  bool get claimed => _claimed;

  DateTime? _missionDate;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// The UTC date string for which the current mission is active.
  String _dateKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  /// Loads persisted mission state. If the stored mission is from a previous
  /// UTC day, or no mission exists, a new one is generated for today.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final rawDate = prefs.getString(_keyMissionDate);
    final today = DateTime.now().toUtc();
    final todayKey = _dateKey(today);

    if (rawDate != null && rawDate == todayKey) {
      // Same day — restore saved mission and flags.
      final rawMission = prefs.getString(_keyMission);
      if (rawMission != null) {
        try {
          _mission = DailyMission.fromJson(jsonDecode(rawMission));
        } catch (_) {
          _mission = _pickMission(today);
        }
      } else {
        _mission = _pickMission(today);
      }
      _completed = prefs.getBool(_keyMissionCompleted) ?? false;
      _claimed = prefs.getBool(_keyMissionClaimed) ?? false;
      _missionDate = today;
    } else {
      // New day — generate a fresh mission.
      _missionDate = today;
      _mission = _pickMission(today);
      _completed = false;
      _claimed = false;
      await _save();
    }
    _loaded = true;
    notifyListeners();
  }

  /// Picks a mission deterministically for the given UTC date.
  DailyMission _pickMission(DateTime date) {
    final dayNumber = date.difference(DateTime.utc(2000, 1, 1)).inDays;
    final rng = Random(dayNumber);
    return _missions[rng.nextInt(_missions.length)];
  }

  /// Call after each finished run to update today's best score.
  void checkScore(int score) {
    if (!_loaded) return;
    if (score > _bestScoreToday) {
      _bestScoreToday = score;
      notifyListeners();
    }
    if (!_completed && score >= (_mission?.targetScore ?? 0)) {
      _completed = true;
      notifyListeners();
    }
  }

  /// Claims the mission reward. Awards coins to the skill wallet and resets
  /// for a new mission on the next UTC day.
  Future<void> claim() async {
    if (!_loaded || !_completed || _claimed || _mission == null) return;

    await SkillController.instance.awardCoins(_mission!.rewardCoins);
    _claimed = true;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_mission != null) {
      await prefs.setString(_keyMission, jsonEncode(_mission!.toJson()));
    }
    await prefs.setBool(_keyMissionCompleted, _completed);
    await prefs.setBool(_keyMissionClaimed, _claimed);
    if (_missionDate != null) {
      await prefs.setString(_keyMissionDate, _dateKey(_missionDate!));
    }
  }

  /// Resets mission state for the current day (used for testing).
  Future<void> resetForTest() async {
    final today = DateTime.now().toUtc();
    _missionDate = today;
    _mission = _pickMission(today);
    _completed = false;
    _claimed = false;
    _bestScoreToday = 0;
    await _save();
    notifyListeners();
  }
}
