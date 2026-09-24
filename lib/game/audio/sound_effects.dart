/// Every one-shot sound effect bundled with the game.
///
/// Each value maps 1:1 to a `.wav` file under `assets/audio/sfx/`.
enum SoundEffect {
  buttonClick('button_click'),
  coinCollect('coin_collect'),
  coinStreak('coin_streak'),
  comboIncrease('combo_increase'),
  crawl('crawl'),
  gameOver('game_over'),
  heal('heal'),
  hit('hit'),
  jump('jump'),
  legendaryAutoStrike('legendary_auto_strike'),
  legendaryGoldRush('legendary_gold_rush'),
  legendaryReverseRun('legendary_reverse_run'),
  legendaryRoadSweep('legendary_road_sweep'),
  legendaryTempest('legendary_tempest'),
  levelComplete('level_complete'),
  menuClose('menu_close'),
  menuOpen('menu_open'),
  powerupMagnet('powerup_magnet'),
  powerupShield('powerup_shield'),
  smash('smash'),
  smashReady('smash_ready'),
  themeTransition('theme_transition');

  const SoundEffect(this.fileStem);

  /// Asset file name without extension (matches the bundled file exactly).
  final String fileStem;

  /// Full Flutter asset path of the effect's sound file.
  String get assetPath => 'assets/audio/sfx/$fileStem.wav';
}
