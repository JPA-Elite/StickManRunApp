import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'skill_controller.dart';

/// One purchasable coin pack: a coin amount for a fixed peso price.
/// Purchases are not yet wired up — tapping a pack shows a "coming soon"
/// placeholder in the shop screen.
@immutable
class CoinPack {
  final int coins;
  final int pesos;

  const CoinPack({required this.coins, required this.pesos});

  static const List<CoinPack> all = [
    CoinPack(coins: 5000, pesos: 100),
    CoinPack(coins: 10000, pesos: 150),
    CoinPack(coins: 20000, pesos: 200),
    CoinPack(coins: 30000, pesos: 250),
    CoinPack(coins: 50000, pesos: 400),
    CoinPack(coins: 1000000, pesos: 650),
  ];
}

/// Singleton controller that owns the coin shop state: the one-time welcome
/// bonus (claimable only once, persisted to SharedPreferences) and the list
/// of purchasable coin packs.
class ShopController extends ChangeNotifier {
  ShopController._();

  static final ShopController instance = ShopController._();

  static const String _keyBonusClaimed = 'shop_bonus_claimed_v1';

  /// Coins granted by the one-time welcome bonus.
  static const int welcomeBonusCoins = 100000;

  bool _bonusClaimed = false;

  /// True once the one-time welcome bonus has been claimed.
  bool get bonusClaimed => _bonusClaimed;

  /// True while the welcome bonus is still available to claim.
  bool get bonusAvailable => !_bonusClaimed;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Loads persisted shop state (idempotent).
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _bonusClaimed = prefs.getBool(_keyBonusClaimed) ?? false;
    _loaded = true;
    notifyListeners();
  }

  /// Claims the one-time welcome bonus, awarding [welcomeBonusCoins] to the
  /// coin wallet. Returns false when it was already claimed.
  Future<bool> claimBonus() async {
    if (_bonusClaimed) return false;
    _bonusClaimed = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBonusClaimed, true);
    await SkillController.instance.awardCoins(welcomeBonusCoins);
    notifyListeners();
    return true;
  }

  /// Resets every field so a fresh [load] reproduces a clean player state.
  /// Test-only; not used by production code.
  @visibleForTesting
  void debugResetForTests() {
    _bonusClaimed = false;
    _loaded = false;
  }
}
