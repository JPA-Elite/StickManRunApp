import 'package:flutter/material.dart';

import '../settings/skill_controller.dart';
import '../settings/skill_defs.dart';

/// Dark arcade-style page for purchasing the always-active skill upgrades,
/// funded by coins collected during runs.
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  final Color _accent = const Color(0xFF4DD8FF);
  final Color _gold = const Color(0xFFFFD700);

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
                  Expanded(
                    child: Text(
                      'SKILLS',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
            ),
            const Divider(color: Colors.yellow, height: 1),
            ListenableBuilder(
              listenable: SkillController.instance,
              builder: (context, _) {
                final sc = SkillController.instance;
                final actives =
                    SkillDef.all.where((d) => sc.tierOf(d.id) > 0).length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatPlate(
                        label: 'COINS',
                        value: '${sc.wallet}',
                        icon: Icons.monetization_on,
                        iconColor: _gold,
                      ),
                      _StatPlate(
                        label: 'EARNED',
                        value: '${sc.totalEarned}',
                        icon: Icons.trending_up,
                        iconColor: _accent,
                      ),
                      _StatPlate(
                        label: 'ACTIVE',
                        value: '$actives',
                        icon: Icons.workspaces_outline,
                        iconColor: Colors.greenAccent,
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: SkillController.instance,
                builder: (context, _) {
                  final sc = SkillController.instance;
                  final actives = SkillDef.all.where((d) => sc.tierOf(d.id) > 0).length;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '$actives OF ${SkillDef.all.length} SKILLS ACTIVE · ALWAYS-ON',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      for (final def in SkillDef.all) _SkillCard(def: def),
                    ],
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

class _StatPlate extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatPlate({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final SkillDef def;

  const _SkillCard({required this.def});

  @override
  Widget build(BuildContext context) {
    final sc = SkillController.instance;
    final tier = sc.tierOf(def.id);
    final isMaxed = sc.isMaxed(def.id);
    final cost = sc.nextCost(def.id);
    final canAfford = !isMaxed && sc.wallet >= cost;

    final accent = def.isCombo
        ? const Color(0xFF4DD8FF)
        : const Color(0xFFFFD700);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: accent.withValues(alpha: isMaxed ? 0.8 : 0.4),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  def.icon,
                  style: TextStyle(
                    color: accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _TierPips(current: tier, max: def.maxTier, accent: accent),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isMaxed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'MAX',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: canAfford
                      ? () => SkillController.instance.upgrade(def.id)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAfford ? accent : null,
                    foregroundColor: canAfford ? Colors.black : Colors.white,
                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    '${canAfford ? 'UPGRADE ' : ''}${cost}◆',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            def.description,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierPips extends StatelessWidget {
  final int current;
  final int max;
  final Color accent;

  const _TierPips({
    required this.current,
    required this.max,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < max; i++)
          Container(
            width: 16,
            height: 6,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: i < current
                  ? accent
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}