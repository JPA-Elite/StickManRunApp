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

  int _wallet = 0;

  /// Spendable coin balance (coins earned minus coins spent on skills).
  int get wallet => _wallet;

  /// Lifetime coins earned across all runs (before spending).
  int _totalEarned = 0;
  int get totalEarned => _totalEarned;

  Map<SkillId, int> _tiers = {};

  /// Owned legendary skills (single-purchase, no tiers).
  Set<LegendarySkill> _legendaries = {};

  /// Owned legendary skills, exposed for engine config.
  Set<LegendarySkill> get owned => Set.unmodifiable(_legendaries);

  /// True when the legendary skill has been purchased.
  bool hasLegendary(LegendarySkill id) => _legendaries.contains(id);

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

  SkillConfig get config =>
      SkillConfig.fromTiers(Map.of(_tiers));

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
            ): (e.value as num).toInt(),
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
      jsonEncode({
        for (final e in _tiers.entries) e.key.name: e.value,
      }),
    );
    notifyListeners();
    return true;
  }

  /// Attempts to purchase the legendary skill [id]. Returns false if already
  /// owned or the wallet cannot afford it.
  Future<bool> purchase(LegendarySkill id) async {
    final def = LegendaryDef.forId(id);
    if (_legendaries.contains(id)) return false;
    if (_wallet < def.cost) return false;

    _wallet -= def.cost;
    _legendaries.add(id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWallet, _wallet);
    await prefs.setString(
      _keyLegendaries,
      jsonEncode(_legendaries.map((s) => s.name).toList()),
    );
    notifyListeners();
    return true;
  }
}