import 'package:flutter/material.dart';

import '../settings/daily_mission.dart';
import '../settings/daily_streak.dart';
import '../settings/skill_controller.dart';

/// Daily check-in streak page. Shows the current streak, allows manual
/// check-in, displays the rewards track, and lists past check-in history.
class DailyStreakScreen extends StatefulWidget {
  const DailyStreakScreen({super.key});

  @override
  State<DailyStreakScreen> createState() => _DailyStreakScreenState();
}

class _DailyStreakScreenState extends State<DailyStreakScreen>
    with TickerProviderStateMixin {
  /// Drives the streak-milestone celebration overlay.
  int? _celebrateStreak;

  late final AnimationController _celebrationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.month)}/${two(local.day)}';
  }

  void _checkIn() async {
    final controller = DailyStreakController.instance;
    final awarded = await controller.checkIn();
    if (!mounted) return;
    if (awarded != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Claimed $awarded◆!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      // Celebrate when hitting a milestone streak.
      final streak = controller.currentStreak;
      if (DailyStreakController.streakRewards.containsKey(streak)) {
        setState(() => _celebrateStreak = streak);
        _celebrationController.forward(from: 0);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _celebrationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _celebrateStreak = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = DailyStreakController.instance;

    return Stack(
      children: [
        Scaffold(
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
                                'DAY STREAK',
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                checkedIn
                                    ? 'Claimed for today. See you tomorrow!'
                                    : 'Check in today to keep your streak alive!',
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Check-in button (primary action).
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: checkedIn ? null : _checkIn,
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              checkedIn
                                  ? 'CHECKED IN TODAY ✓'
                                  : 'CHECK IN +$nextReward◆',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _HowItWorks(),
                        const SizedBox(height: 16),

                        // Milestone countdown progress bar.
                        _MilestoneProgress(
                          streak: streak,
                          controller: controller,
                        ),
                        const SizedBox(height: 12),

                        // 7-day calendar strip with legend.
                        _SevenDayCalendar(
                          streak: streak,
                          checkedInToday: checkedIn,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendChip(
                              icon: Icons.check_circle,
                              color: Colors.orangeAccent,
                              label: 'CLAIMED',
                            ),
                            _LegendChip(
                              isToday: true,
                              color: Colors.yellow,
                              label: 'TODAY',
                            ),
                            _LegendChip(
                              icon: Icons.lock_outline,
                              color: Colors.white54,
                              label: 'LOCKED',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Personal best + stats row.
                        _StreakStats(controller: controller),
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
                                'NEXT: $nextReward◆${nextMilestone > 0 ? ' +$nextMilestone◆ BONUS' : ''}',
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

                        // Daily mission card.
                        ListenableBuilder(
                          listenable: DailyMissionController.instance,
                          builder: (context, _) {
                            final missionCtrl = DailyMissionController.instance;
                            return _DailyMissionCard(controller: missionCtrl);
                          },
                        ),
                        const SizedBox(height: 16),

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
        ),
      if (_celebrateStreak != null) _buildCelebration(_celebrateStreak!),
    ],
    );
  }

  /// Full-screen overlay celebrating a streak milestone check-in.
  Widget _buildCelebration(int streak) {
    final reward = DailyStreakController.streakRewards[streak] ?? 0;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dim backdrop.
            AnimatedBuilder(
              animation: _celebrationController,
              builder: (context, _) {
                final v = _celebrationController.value;
                final fade = v > 0.7 ? (1.0 - (v - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
                return Container(
                  color: Colors.black.withValues(alpha: 0.7 * fade),
                );
              },
            ),
            // Celebrating banner.
            Center(
              child: AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, _) {
                  final v = _celebrationController.value;
                  final scale = Curves.elasticOut.transform(v);
                  final fade = v > 0.7 ? (1.0 - (v - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
                  return Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: 0.5 + scale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF140B24),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orangeAccent, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orangeAccent.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.orangeAccent,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$streak DAY STREAK!',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'MILESTONE BONUS: +$reward◆',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'KEEP IT UP!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// Short explainer telling players how the daily streak works.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'HOW IT WORKS',
            style: TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 8),
          _BulletPoint(
            icon: Icons.local_fire_department,
            text: 'Check in once a day to keep your streak alive.',
          ),
          SizedBox(height: 6),
          _BulletPoint(
            icon: Icons.notifications_active,
            text: 'Miss a day? Your streak resets to zero.',
          ),
          SizedBox(height: 6),
          _BulletPoint(
            icon: Icons.card_giftcard,
            text: 'Reach milestone days (3, 7, 14, 30) for bonus coins.',
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BulletPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.orangeAccent, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small legend chip explaining the calendar cell states.
class _LegendChip extends StatelessWidget {
  final IconData? icon;
  final bool isToday;
  final Color color;
  final String label;

  const _LegendChip({
    this.icon,
    this.isToday = false,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, color: color, size: 12)
          else
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.yellow.withValues(alpha: 0.15),
                border: Border.all(color: Colors.yellow, width: 1),
              ),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress bar showing how far the player is from the next streak milestone
/// and the bonus coins they will unlock.
class _MilestoneProgress extends StatelessWidget {
  final int streak;
  final DailyStreakController controller;

  const _MilestoneProgress({
    required this.streak,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final next = controller.nextMilestoneKey;
    final reward = controller.nextMilestoneReward;
    final daysLeft = controller.daysUntilNextMilestone;
    final progress = (streak / (next ?? 1)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                next == null ? 'MAX MILESTONE REACHED' : 'NEXT MILESTONE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              if (next != null)
                Text(
                  'DAY $next · +$reward◆',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            next == null
                ? 'ALL MILESTONES UNLOCKED!'
                : '$daysLeft DAY${daysLeft == 1 ? '' : 'S'} TO $reward◆ BONUS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact 7-day reward strip: achieved days show a check, today pulses
/// "CLAIM", and locked days preview their reward (or a lock).
class _SevenDayCalendar extends StatefulWidget {
  final int streak;
  final bool checkedInToday;

  const _SevenDayCalendar({
    required this.streak,
    required this.checkedInToday,
  });

  @override
  State<_SevenDayCalendar> createState() => _SevenDayCalendarState();
}

class _SevenDayCalendarState extends State<_SevenDayCalendar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streak = widget.streak;
    final todayIndex = widget.checkedInToday ? streak : streak + 1;

    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          if (day > 1) const SizedBox(width: 6),
          Expanded(
            child: _CalendarDayCell(
              day: day,
              reward: DailyStreakController.streakRewards[day],
              achieved: streak >= day,
              isToday: todayIndex == day,
              pulse: _pulse,
            ),
          ),
        ],
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final int? reward;
  final bool achieved;
  final bool isToday;
  final Animation<double> pulse;

  const _CalendarDayCell({
    required this.day,
    required this.reward,
    required this.achieved,
    required this.isToday,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final color = achieved
        ? Colors.orangeAccent
        : isToday
            ? Colors.yellow
            : Colors.white.withValues(alpha: 0.35);
    final bg = achieved
        ? Colors.orangeAccent.withValues(alpha: 0.25)
        : isToday
            ? Colors.yellow.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05);

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = isToday
            ? BoxShadow(
                color: Colors.yellow.withValues(alpha: 0.3 + 0.4 * pulse.value),
                blurRadius: 6 + 8 * pulse.value,
              )
            : null;
        return Container(
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: bg,
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.2),
            boxShadow: glow != null ? [glow] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'DAY $day',
                style: TextStyle(
                  color: isToday ? Colors.white : color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              if (achieved)
                const Icon(Icons.check_circle, color: Colors.orangeAccent, size: 16)
              else if (isToday)
                Text(
                  'CLAIM',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else if (reward != null)
                Text(
                  '$reward◆',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else
                const Icon(Icons.lock_outline, color: Colors.white38, size: 14),
            ],
          ),
        );
      },
    );
  }
}

/// Row of lifetime stats: best streak and total coins earned.
class _StreakStats extends StatelessWidget {
  final DailyStreakController controller;

  const _StreakStats({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.emoji_events,
            label: 'BEST',
            value: '${controller.bestStreak} DAYS',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.monetization_on,
            label: 'EARNED',
            value: '${controller.totalRewarded}◆',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orangeAccent, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
        ],
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
            '$reward◆',
            style: TextStyle(
              color: achieved
                  ? Colors.orangeAccent
                  : Colors.white.withValues(alpha: 0.4),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
