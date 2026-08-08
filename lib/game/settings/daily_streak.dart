import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'skill_controller.dart';

/// Singleton controller that tracks the player's daily check-in streak, persists
/// the data to SharedPreferences, and awards coins from [SkillController].
///
/// A "day" is defined as UTC midnight to UTC midnight. If the player does not
/// check in for at least one full UTC day, the streak resets.
class DailyStreakController extends ChangeNotifier {
  DailyStreakController._();

  static final DailyStreakController instance = DailyStreakController._();

  static const String _keyLastCheckIn = 'daily_streak_last_checkin_v1';
  static const String _keyStreakDays = 'daily_streak_days_v1';
  static const String _keyTotalCheckIns = 'daily_streak_total_v1';
  static const String _keyBestStreak = 'daily_streak_best_v1';

  /// Rewards (in coins) granted for completing a streak of this length.
  /// Indexed by streak day count. The player receives the tier corresponding
  /// to their current streak after checking in.
  static const Map<int, int> streakRewards = {
    1: 50,
    3: 200,
    7: 500,
    14: 1000,
    30: 2500,
  };

  /// Base daily reward plus a small scaling bonus per streak day.
  int _dailyReward(int streakDays) => 50 + (streakDays * 10);

  /// Consecutive check-in dates (UTC midnight) most-recent first.
  final List<DateTime> _streakDates = [];
  List<DateTime> get streakDates => List.unmodifiable(_streakDates);

  /// Lifetime total check-ins (never resets).
  int _totalCheckIns = 0;
  int get totalCheckIns => _totalCheckIns;

  /// Longest streak ever achieved (never resets on a broken streak).
  int _bestStreak = 0;
  int get bestStreak => _bestStreak;

  DateTime? _lastCheckInDate;

  /// Current consecutive streak length.
  int get currentStreak => _streakDates.length;

  /// Total coins the player has been awarded from streak rewards.
  int _totalRewarded = 0;
  int get totalRewarded => _totalRewarded;

  /// The next streak milestone key greater than the current streak, or `null`
  /// when the current streak already exceeds the top milestone.
  int? get nextMilestoneKey {
    if (streakRewards.isEmpty) return null;
    final keys = streakRewards.keys.toList()..sort();
    for (final k in keys) {
      if (k > currentStreak) return k;
    }
    return null;
  }

  /// Days left (including today) until the next streak milestone.
  int get daysUntilNextMilestone {
    final next = nextMilestoneKey;
    if (next == null) return 0;
    final remaining = next - currentStreak;
    return remaining > 0 ? remaining : 0;
  }

  /// Reward coins granted for the next milestone (0 when none remain).
  int get nextMilestoneReward {
    final next = nextMilestoneKey;
    if (next == null) return 0;
    return streakRewards[next] ?? 0;
  }

  /// Whether the player has already checked in today (UTC).
  bool get checkedInToday {
    if (_lastCheckInDate == null) return false;
    final today = DateTime.now().toUtc();
    return _lastCheckInDate!.year == today.year &&
        _lastCheckInDate!.month == today.month &&
        _lastCheckInDate!.day == today.day;
  }

  /// Coins the player will receive on the next check-in.
  int get nextReward => _dailyReward(currentStreak);

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Loads persisted streak data (idempotent).
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _lastCheckInDate = _parseDate(prefs.getString(_keyLastCheckIn));

    final rawDates = prefs.getStringList(_keyStreakDays);
    if (rawDates != null) {
      _streakDates
        ..clear()
        ..addAll(
          rawDates
              .map((s) => _parseDate(s))
              .whereType<DateTime>()
              .toList()
            ..sort((a, b) => b.compareTo(a)),
        );
    }

    // Prune any dates that are before yesterday (streak already broken).
    _pruneToCurrentStreak();

    _totalCheckIns = prefs.getInt(_keyTotalCheckIns) ?? 0;
    _bestStreak = prefs.getInt(_keyBestStreak) ?? _streakDates.length;
    _loaded = true;
    notifyListeners();
  }

  /// Parses a UTC date string back to a DateTime at midnight UTC.
  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  String _formatDate(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  void _pruneToCurrentStreak() {
    final today = DateTime.now().toUtc();
    // Keep only dates that are part of the current consecutive streak.
    final valid = <DateTime>[];
    DateTime? expected;
    for (final d in _streakDates) {
      if (expected == null) {
        // First entry should be yesterday or today.
        final dayDiff = today.difference(d).inDays;
        if (dayDiff == 0 || dayDiff == 1) {
          valid.add(d);
          expected = d.subtract(const Duration(days: 1));
        }
      } else if (d.year == expected.year &&
          d.month == expected.month &&
          d.day == expected.day) {
        valid.add(d);
        expected = d.subtract(const Duration(days: 1));
      }
    }
    _streakDates.clear();
    _streakDates.addAll(valid);
  }

  /// Attempts to check in for today. Returns the number of coins awarded, or
  /// `null` if already checked in today.
  Future<int?> checkIn() async {
    if (!_loaded) await load();
    if (checkedInToday) return null;

    final today = DateTime.now().toUtc();

    if (_lastCheckInDate != null) {
      final dayDiff = today.difference(_lastCheckInDate!).inDays;
      if (dayDiff >= 2) {
        // Streak broken — reset.
        _streakDates.clear();
      }
    }

    _streakDates.insert(0, today);
    _lastCheckInDate = today;
    _totalCheckIns++;
    if (_streakDates.length > _bestStreak) {
      _bestStreak = _streakDates.length;
    }

    int awarded = _dailyReward(_streakDates.length - 1);

    // Milestone bonus.
    if (streakRewards.containsKey(_streakDates.length)) {
      awarded += streakRewards[_streakDates.length]!;
    }

    _totalRewarded += awarded;
    await _save();
    await SkillController.instance.awardCoins(awarded);
    notifyListeners();
    return awarded;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastCheckInDate != null) {
      await prefs.setString(_keyLastCheckIn, _formatDate(_lastCheckInDate!));
    }
    await prefs.setStringList(
      _keyStreakDays,
      _streakDates.map(_formatDate).toList(),
    );
    await prefs.setInt(_keyTotalCheckIns, _totalCheckIns);
    await prefs.setInt(_keyBestStreak, _bestStreak);
  }
}
