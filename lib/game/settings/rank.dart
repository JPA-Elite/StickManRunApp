/// Cinematic rank tiers, driven by total accumulated score.
/// L1 = <10k, L2 = 10k–20k, L3 = 20k–30k, and so on.
class RankTier {
  final int level;
  final String name;
  final int nextMilestone;

  const RankTier({
    required this.level,
    required this.name,
    required this.nextMilestone,
  });
}

const List<String> rankTierNames = [
  'ROOKIE',
  'RUNNER',
  'SPRINTER',
  'DASHER',
  'ACROBAT',
  'LEGEND',
];

/// Maps a lifetime total score to its rank tier.
RankTier rankForScore(int total) {
  final level = (total ~/ 10000 + 1).clamp(1, rankTierNames.length);
  final name = rankTierNames[level - 1];
  return RankTier(
    level: level,
    name: name,
    nextMilestone: level * 10000,
  );
}
