import 'package:flutter/material.dart';

import '../settings/daily_mission.dart';
import '../settings/daily_streak.dart';
import '../settings/skill_controller.dart';

/// Daily check-in streak page. Shows the current streak, allows manual
/// check-in, displays the rewards track, and lists past check-in history.
class DailyStreakScreen extends StatelessWidget {
  const DailyStreakScreen({super.key});

  String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.month)}/${two(local.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = DailyStreakController.instance;

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
                      'DAILY STREAK',
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
                listenable: controller,
                builder: (context, _) {
                  final streak = controller.currentStreak;
                  final checkedIn = controller.checkedInToday;
                  final wallet = SkillController.instance.wallet;
                  final nextReward = controller.nextReward;
                  final nextMilestone = controller.nextMilestoneReward;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Streak counter card.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.orangeAccent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.orangeAccent.withValues(alpha: 0.12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.orangeAccent
                                    .withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                color: Colors.orangeAccent,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 36,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'DAYS STREAK',
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Wallet + next reward.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFFD700)
                                  .withValues(alpha: 0.45),
                            ),
                            color: Colors.white.withValues(alpha: 0.06),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x1F_D7FF_FF),
                                Color(0x0A_FFFFFF),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: Color(0xFFFFD700),
                                size: 18,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'WALLET: $wallet',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'NEXT: ${nextReward}◆${nextMilestone > 0 ? ' +${nextMilestone}◆ BONUS' : ''}',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                         ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 16),

                        // Daily mission card.
                        ListenableBuilder(
                          listenable: DailyMissionController.instance,
                          builder: (context, _) {
                            final missionCtrl = DailyMissionController.instance;
                            return _DailyMissionCard(controller: missionCtrl);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Check-in button.
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: checkedIn
                                ? null
                                : () async {
                                    final awarded =
                                        await controller.checkIn();
                                    if (awarded != null && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Claimed $awarded◆!'),
                                          backgroundColor:
                                              Colors.orangeAccent,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: checkedIn
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.orangeAccent,
                              foregroundColor: Colors.black,
                              disabledForegroundColor:
                                  Colors.white.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              checkedIn ? 'CLAIMED TODAY' : 'CLAIM $nextReward◆',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Rewards track.
                        const Text(
                          'STREAK REWARDS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final entry
                                in DailyStreakController.streakRewards.entries)
                              _RewardBadge(
                                day: entry.key,
                                reward: entry.value,
                                isCurrent: streak == entry.key,
                                achieved: streak >= entry.key,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // History.
                        if (controller.streakDates.isNotEmpty) ...[
                          const Text(
                            'RECENT CHECK-INS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              for (final dt in controller.streakDates)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _fmtDate(dt),
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.orangeAccent,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'TOTAL CHECK-INS: ${controller.totalCheckIns}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
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

/// Card displaying today's daily mission: target score, progress, and a
/// claim button that awards the coin reward.
class _DailyMissionCard extends StatelessWidget {
  final DailyMissionController controller;

  const _DailyMissionCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final mission = controller.mission;
    if (mission == null) {
      return const SizedBox.shrink();
    }

    final target = mission.targetScore;
    final reward = mission.rewardCoins;
    final progress = controller.bestScoreToday;
    final pct = (progress / target).clamp(0.0, 1.0);
    final completed = controller.completed;
    final claimed = controller.claimed;

    final bgColor = completed
        ? Colors.orangeAccent.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.06);
    final borderColor = completed
        ? Colors.orangeAccent
        : Colors.white.withValues(alpha: 0.3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: bgColor,
        border: Border.all(color: borderColor, width: 1.4),
        gradient: completed
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.orangeAccent.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.4),
                ],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: title + reward.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DAILY MISSION',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '$reward◆',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Description.
          Text(
            mission.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),

          // Progress bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$progress / $target',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),

          // Action button.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: claimed
                  ? null
                  : completed
                      ? () async {
                          await controller.claim();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Claimed $reward◆!'),
                                backgroundColor: Colors.orangeAccent,
                              ),
                            );
                          }
                        }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: claimed
                    ? Colors.white.withValues(alpha: 0.08)
                    : completed
                        ? Colors.orangeAccent
                        : Colors.white.withValues(alpha: 0.08),
                foregroundColor: claimed
                    ? Colors.white.withValues(alpha: 0.5)
                    : completed
                        ? Colors.black
                        : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                claimed
                    ? 'CLAIMED ✓'
                    : completed
                        ? 'CLAIM REWARD'
                        : 'IN PROGRESS',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  final int day;
  final int reward;
  final bool isCurrent;
  final bool achieved;

  const _RewardBadge({
    required this.day,
    required this.reward,
    required this.isCurrent,
    required this.achieved,
  });

  @override
  Widget build(BuildContext context) {
    final bg = achieved
        ? Colors.orangeAccent.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.05);
    final border = achieved
        ? Colors.orangeAccent
        : Colors.white.withValues(alpha: 0.2);

    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bg,
        border: Border.all(color: border, width: 1.2),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: Colors.orangeAccent.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DAY $day',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${achieved ? reward : "?"}◆',
            style: TextStyle(
              color: achieved ? Colors.orangeAccent : Colors.white
                  .withValues(alpha: 0.3),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
