/// Every looping background music track bundled with the game.
///
/// Each value maps to an `.mp3` file under `assets/audio/music/` (universally
/// decodable: Android, iOS/macOS AVFoundation, and all web browsers).
/// Legacy `.ogg` files are kept on disk as fallback for older installs.
enum BackgroundMusic {
  menuTheme('menu_theme'),

  /// Biome tracks; [biomeIndex] mirrors the engine's randomThemeIndex
  /// (0=forest, 1=desert, 2=night city, 3=dark cave, 4=volcano).
  gameplayForest('gameplay_forest', biomeIndex: 0),
  gameplayDesert('gameplay_desert', biomeIndex: 1),
  gameplayNightCity('gameplay_nightcity', biomeIndex: 2),
  gameplayDarkCave('gameplay_cave', biomeIndex: 3),
  gameplayVolcano('gameplay_volcano', biomeIndex: 4);

  const BackgroundMusic(this.fileStem, {this.biomeIndex});

  /// Asset file name without extension (matches the bundled file exactly).
  final String fileStem;

  /// Engine biome index this track belongs to; null for non-gameplay tracks.
  final int? biomeIndex;

  /// Full Flutter asset path of the track (MP3 = universal support).
  String get assetPath => 'assets/audio/music/$fileStem.mp3';

  /// Legacy OGG path, tried only if the MP3 fails to load.
  String get fallbackAssetPath => 'assets/audio/music/$fileStem.ogg';

  /// Whether this track loops over world biomes during gameplay.
  bool get isGameplayTrack => biomeIndex != null;

  /// Resolves the engine's [biomeIndex] (see StickmanRunSnapshot
  /// .randomThemeIndex) to its looping track. Returns null out of range.
  static BackgroundMusic? forBiomeIndex(int biomeIndex) {
    for (final track in BackgroundMusic.values) {
      if (track.biomeIndex == biomeIndex) return track;
    }
    return null;
  }
}
