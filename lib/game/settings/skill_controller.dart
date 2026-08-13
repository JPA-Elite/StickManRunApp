import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'legendary_defs.dart';
import 'skill_defs.dart';

/// Singleton controller that owns the player's owned skill tiers and their
/// coin wallet. Coins are earned from finished runs and spent to upgrade
/// skills. This state is persisted independently from the score history so it
/// survives "clear score history".
class SkillController extends ChangeNotifier {
  SkillController._();

  static final SkillController instance = SkillController._();

  static const String _keyWallet = 'skill_wallet_v1';
  static const String _keyEarned = 'skill_earned_v1';
  static const String _keyTiers = 'skill_tiers_v1';
  static const String _keyLegendaries = 'legendary_owned_v1';
  static const String _keyActiveLegendaries = 'legendary_active_v1';

  int _wallet = 0;

  /// Spendable coin balance (coins earned minus coins spent on skills).
  int get wallet => _wallet;

  /// Lifetime coins earned across all runs (before spending).
  int _totalEarned = 0;
  int get totalEarned => _totalEarned;

  Map<SkillId, int> _tiers = {};

  /// Permanent collection of legendary skills (single-purchase, no tiers).
  /// Never shrinks once a skill is bought.
  Set<LegendarySkill> _legendaries = {};

  /// The legendaries currently equipped in the active slots, ≤ [maxLegendaries].
  Set<LegendarySkill> _active = {};

  /// Every legendary skill the player has permanently purchased.
  Set<LegendarySkill> get owned => Set.unmodifiable(_legendaries);

  /// The legendaries currently equipped (usable in a run), ≤ [maxLegendaries].
  Set<LegendarySkill> get active => Set.unmodifiable(_active);

  /// Maximum number of legendary skills that can be equipped at once.
  static const int maxLegendaries = 2;

  /// Number of legendary skills in the permanent collection.
  int get legendaryCount => _legendaries.length;

  /// True when all [maxLegendaries] equip slots are filled.
  bool get activeSlotsFull => _active.length >= maxLegendaries;

  /// True when the legendary skill has been permanently purchased.
  bool hasLegendary(LegendarySkill id) => _legendaries.contains(id);

  /// True when the legendary skill is currently equipped in an active slot.
  bool isActive(LegendarySkill id) => _active.contains(id);

  /// Cooldown between triggers of the same legendary skill.
  static const int legendaryCooldownMicros = 20000000; // 20s

  /// Timestamp (microsSinceEpoch) of the last time each legendary was
  /// triggered, kept in memory for the current app session. Like the old
  /// run-screen map this persists across runs/restarts within the session but
  /// is never written to disk.
  final Map<LegendarySkill, int> _lastLegendaryUseMicros = {};

  /// Records a legendary activation so the shared cooldown is visible from
  /// the run HUD and the skills page alike.
  void recordLegendaryUse(LegendarySkill id) {
    _lastLegendaryUseMicros[id] = DateTime.now().microsecondsSinceEpoch;
    notifyListeners();
  }

  /// Clears every legendary cooldown. Called when a run starts (retry or a
  /// newly selected level) so skills are immediately ready again.
  void resetLegendaryCooldowns() {
    _lastLegendaryUseMicros.clear();
    notifyListeners();
  }

  /// Seconds (>= 0) until [id] can be used again. 0 means it is ready.
  double legendaryCooldownRemainingSec(LegendarySkill id) {
    final last = _lastLegendaryUseMicros[id];
    if (last == null) return 0;
    final elapsedMicros = DateTime.now().microsecondsSinceEpoch - last;
    final remaining = (legendaryCooldownMicros - elapsedMicros) / 1e6;
    return remaining < 0 ? 0 : remaining;
  }

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Owned tier (0..max) for the given skill.
  int tierOf(SkillId id) => _tiers[id] ?? 0;

  /// True when the skill is at its maximum tier.
  bool isMaxed(SkillId id) => tierOf(id) >= SkillDef.forId(id).maxTier;

  /// Cost to upgrade to the next tier from the current one (0 when maxed).
  int nextCost(SkillId id) {
    final def = SkillDef.forId(id);
    final t = tierOf(id);
    if (t >= def.maxTier) return 0;
    return def.costs[t];
  }

  SkillConfig get config => SkillConfig.fromTiers(Map.of(_tiers));

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _wallet = prefs.getInt(_keyWallet) ?? 0;
    _totalEarned = prefs.getInt(_keyEarned) ?? 0;
    final raw = prefs.getString(_keyTiers);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = (jsonDecode(raw) as Map<String, dynamic>);
        _tiers = {
          for (final e in map.entries)
            SkillId.values.firstWhere(
              (s) => s.name == e.key,
              orElse: () => SkillId.coinMagnet,
            ): (e.value as num)
                .toInt(),
        };
      } catch (_) {
        _tiers = {};
      }
    }
    final legRaw = prefs.getString(_keyLegendaries);
    if (legRaw != null && legRaw.isNotEmpty) {
      try {
        final list = (jsonDecode(legRaw) as List<dynamic>);
        _legendaries = {
          for (final e in list)
            LegendarySkill.values.firstWhere(
              (s) => s.name == e,
              orElse: () => LegendarySkill.autoStrike,
            ),
        };
      } catch (_) {
        _legendaries = {};
      }
    }
    final activeRaw = prefs.getString(_keyActiveLegendaries);
    if (activeRaw != null && activeRaw.isNotEmpty) {
      try {
        final list = (jsonDecode(activeRaw) as List<dynamic>);
        final parsed = {
          for (final e in list)
            LegendarySkill.values.firstWhere(
              (s) => s.name == e,
              orElse: () => LegendarySkill.autoStrike,
            ),
        };
        _active = parsed
            .where(_legendaries.contains)
            .take(maxLegendaries)
            .toSet();
      } catch (_) {
        _active = {};
      }
    }
    // Legacy saves predate the active-slot concept: derive the equipped set
    // from the first owned skills so the player keeps their loadout.
    if (_active.isEmpty && _legendaries.isNotEmpty) {
      _active = _legendaries.take(maxLegendaries).toSet();
    }
    _loaded = true;
    notifyListeners();
  }

  /// Adds collected coins from a finished run to the wallet.
  Future<void> awardCoins(int coins) async {
    if (coins <= 0) return;
    _wallet += coins;
    _totalEarned += coins;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWallet, _wallet);
    await prefs.setInt(_keyEarned, _totalEarned);
    notifyListeners();
  }

  /// Attempts to upgrade [id] to its next tier. Returns false if already maxed
  /// or the wallet cannot afford it.
  Future<bool> upgrade(SkillId id) async {
    final def = SkillDef.forId(id);
    final t = tierOf(id);
    if (t >= def.maxTier) return false;
    final cost = def.costs[t];
    if (_wallet < cost) return false;

    _wallet -= cost;
    _tiers[id] = t + 1;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWallet, _wallet);
    await prefs.setString(
      _keyTiers,
      jsonEncode({for (final e in _tiers.entries) e.key.name: e.value}),
    );
    notifyListeners();
    return true;
  }

  /// Attempts to permanently purchase the legendary skill [id]. Buying is never
  /// blocked by full equip slots — the skill joins the collection and is
  /// auto-equipped when an active slot is free. Returns false if already
  /// owned or the wallet cannot afford it.
  Future<bool> purchase(LegendarySkill id) async {
    final def = LegendaryDef.forId(id);
    if (_legendaries.contains(id)) return false;
    if (_wallet < def.cost) return false;

    _wallet -= def.cost;
    _legendaries.add(id);
    if (_active.length < maxLegendaries) {
      _active.add(id);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWallet, _wallet);
    await prefs.setString(
      _keyLegendaries,
      jsonEncode(_legendaries.map((s) => s.name).toList()),
    );
    await prefs.setString(
      _keyActiveLegendaries,
      jsonEncode(_active.map((s) => s.name).toList()),
    );
    notifyListeners();
    return true;
  }

  /// Equips an owned legendary [skill] into an active slot, free of charge:
  /// the skill was already purchased permanently, so the wallet is never
  /// touched. When every slot is busy, [replaced] — an id that must currently
  /// be equipped — is evicted back into the collection. Returns false if
  /// [skill] is not owned/equipped already or [replaced] is not equipped.
  Future<bool> equipLegendary(
    LegendarySkill skill, {
    required LegendarySkill? replaced,
  }) async {
    if (!_legendaries.contains(skill)) return false;
    if (skill == replaced) return false;
    if (_active.contains(skill)) return false;

    if (_active.length >= maxLegendaries) {
      if (replaced == null || !_active.contains(replaced)) return false;
      _active.remove(replaced);
    }
    _active.add(skill);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyActiveLegendaries,
      jsonEncode(_active.map((s) => s.name).toList()),
    );
    notifyListeners();
    return true;
  }

  /// Resets every field so a fresh [load] reproduces a clean player state.
  /// Test-only; not used by production code.
  @visibleForTesting
  void debugResetForTests() {
    _wallet = 0;
    _totalEarned = 0;
    _tiers = {};
    _legendaries = {};
    _active = {};
    _lastLegendaryUseMicros.clear();
    _loaded = false;
  }
}
