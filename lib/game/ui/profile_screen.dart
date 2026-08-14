import 'package:flutter/material.dart';

import '../settings/daily_mission.dart';
import '../settings/rank.dart';
import '../settings/score_history.dart';
import '../settings/skill_controller.dart';
import 'stickman_avatar.dart';

/// Profile page opened by tapping the avatar on the home header. Shows the
/// player's rank, lifetime stats, and today's daily mission.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'PROFILE',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Divider(color: Colors.yellow, height: 1),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  ScoreHistoryController.instance,
                  SkillController.instance,
                  DailyMissionController.instance,
                ]),
                builder: (context, _) {
                  final history = ScoreHistoryController.instance;
                  final total = history.accumulatedScore;
                  final tier = rankForScore(total);
                  final prevMilestone = (tier.level - 1) * 10000;
                  final progress =
                      tier.level >= rankTierNames.length
                          ? 1.0
                          : ((total - prevMilestone) / 10000).clamp(0.0, 1.0);
                  final mission = DailyMissionController.instance;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Identity card: avatar + rank.
                        _ProfileCard(
                          child: Row(
                            children: [
                              const StickmanAvatar(size: 72),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${tier.name} LV ${tier.level}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.3,
                                        color: Color(0xFFFFD700),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 8,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.12),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF4DD8FF),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tier.level >= rankTierNames.length
                                          ? 'MAX RANK · ${tier.name}'
                                          : '$total / ${tier.nextMilestone} '
                                                'to ${tier.name} ${tier.level + 1}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Lifetime stat tiles.
                        Row(
                          children: [
                            _StatTile(
                              label: 'TOTAL SCORE',
                              value: formatCoinAmount(total),
                              accent: const Color(0xFFFFD700),
                            ),
                            const SizedBox(width: 10),
                            _StatTile(
                              label: 'BEST SCORE',
                              value: formatCoinAmount(history.bestScore),
                              accent: const Color(0xFF4DD8FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _StatTile(
                              label: 'RUNS PLAYED',
                              value: '${history.records.length}',
                              accent: const Color(0xFF4DD8FF),
                            ),
                            const SizedBox(width: 10),
                            _StatTile(
                              label: 'WALLET',
                              value: '${formatCoinAmount(
                                SkillController.instance.wallet,
                              )}◆',
                              accent: const Color(0xFFFFD700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _StatTile(
                              label: 'TOTAL EARNED',
                              value: '${formatCoinAmount(
                                SkillController.instance.totalEarned,
                              )}◆',
                              accent: const Color(0xFFFFD700),
                            ),
                            const SizedBox(width: 10),
                            _StatTile(
                              label: 'TIME PLAYED',
                              value: _formatDuration(
                                history.accumulatedPlaySec,
                              ),
                              accent: const Color(0xFF4DD8FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Daily mission.
                        _ProfileCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(
                                title: "TODAY'S MISSION",
                                accent: Color(0xFFFF5C8A),
                              ),
                              const SizedBox(height: 10),
                              if (mission.mission == null)
                                Text(
                                  'Play a run to unlock today\'s mission.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                )
                              else ...[
                                Text(
                                  mission.mission!.description,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: LinearProgressIndicator(
                                    value: (mission.bestScoreToday /
                                            mission.mission!.targetScore)
                                        .clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.12,
                                    ),
                                    valueColor: const AlwaysStoppedAnimation<
                                      Color
                                    >(Color(0xFFFF5C8A)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mission.claimed
                                      ? 'REWARD CLAIMED · ${mission.mission!.rewardCoins}◆'
                                      : mission.completed
                                      ? 'COMPLETED · claim your ${mission.mission!.rewardCoins}◆ in the Daily Mission screen'
                                      : '${mission.bestScoreToday} / ${mission.mission!.targetScore} · '
                                            '${mission.mission!.rewardCoins}◆ reward',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats a lifetime play time in seconds as a compact human string.
String _formatDuration(double sec) {
  final total = sec.round();
  if (total < 60) return '${total}s';
  final minutes = total ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final rem = minutes % 60;
  return rem > 0 ? '${hours}h ${rem}m' : '${hours}h';
}

/// A bordered dark card used for profile sections.
class _ProfileCard extends StatelessWidget {
  final Widget child;

  const _ProfileCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.yellow.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color accent;

  const _SectionTitle({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: accent,
        fontWeight: FontWeight.w900,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

