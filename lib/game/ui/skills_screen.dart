import 'package:flutter/material.dart';

import '../settings/legendary_defs.dart';
import '../settings/skill_controller.dart';
import '../settings/skill_defs.dart';

/// Cinematic arcade-style page for purchasing the always-active skill upgrades
/// and single-purchase legendary skills, funded by coins collected during runs.
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final Color _gold = const Color(0xFFFFD700);
  final Color _crimson = const Color(0xFFFF5C8A);

  int _tabIndex = 0;

  /// Index of the active tab (0 = STANDARD, 1 = LEGENDARY).
  int get _activeTab => _tabIndex;
  set _activeTab(int v) => _tabIndex = v;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simple vertical dusk gradient so the vivid title pops.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF140B24), Color(0xFF050309)],
                ),
              ),
            ),
          ),
          SafeArea(
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
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Color(0xFFFF5C8A),
                                blurRadius: 22,
                              ),
                              Shadow(
                                color: Color(0xFFFFD700),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ListenableBuilder(
                        listenable: SkillController.instance,
                        builder: (context, _) => _HeaderCoins(
                          wallet: SkillController.instance.wallet,
                          coinColor: _gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.yellow, height: 1),
                Expanded(
                  child: ListenableBuilder(
                    listenable: SkillController.instance,
                    builder: (context, _) {
                      final sc = SkillController.instance;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tabbed STANDARD / LEGENDARY selector.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _TabChip(
                                    label: 'STANDARD ♢',
                                    active: _activeTab == 0,
                                    color: _gold,
                                    onTap: () =>
                                        setState(() => _activeTab = 0),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _TabChip(
                                    label: '★ LEGENDARY',
                                    active: _activeTab == 1,
                                    color: _crimson,
                                    onTap: () =>
                                        setState(() => _activeTab = 1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _activeTab == 0
                                ? _buildStandard(sc)
                                : _buildLegendary(sc),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandard(SkillController sc) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ..._pairs([for (final def in SkillDef.all) _SkillCard(def: def)]),
      ],
    );
  }

  /// Chunks a list of cards into rows of two so the grid gains vertical space.
  /// A lone leftover card keeps the width of a single grid cell (half-width,
  /// never stretched across the whole row).
  List<Widget> _pairs(List<Widget> cards) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      final hasSecond = i + 1 < cards.length;
      rows.add(LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = hasSecond
              ? null
              : (constraints.maxWidth - 12) / 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasSecond)
                Expanded(child: cards[i])
              else
                SizedBox(width: cardWidth, child: cards[i]),
              if (hasSecond) ...[
                const SizedBox(width: 12),
                Expanded(child: cards[i + 1]),
              ],
            ],
          );
        },
      ));
      rows.add(const SizedBox(height: 12));
    }
    return rows;
  }

  Widget _buildLegendary(SkillController sc) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ..._pairs([for (final def in LegendaryDef.all) _LegendaryCard(def: def)]),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: active ? color : Colors.white.withValues(alpha: 0.2),
            width: active ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Compact header badge showing the spendable coin wallet: a gold coin icon
/// with the value, right-aligned in the header row.
class _HeaderCoins extends StatelessWidget {
  final int wallet;
  final Color coinColor;

  const _HeaderCoins({required this.wallet, required this.coinColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: coinColor.withValues(alpha: 0.45)),
        color: Colors.white.withValues(alpha: 0.06),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            coinColor.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on, color: coinColor, size: 18),
          const SizedBox(width: 5),
          Text(
            '$wallet',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
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
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
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
                width: 34,
                height: 34,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _TierPips(current: tier, max: def.maxTier, accent: accent),
                  ],
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.08),
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

class _LegendaryCard extends StatefulWidget {
  final LegendaryDef def;

  const _LegendaryCard({required this.def});

  @override
  State<_LegendaryCard> createState() => _LegendaryCardState();
}

class _LegendaryCardState extends State<_LegendaryCard> {
  static const Color _crimson = Color(0xFFFF5C8A);

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final sc = SkillController.instance;
    final owned = sc.hasLegendary(def.id);
    final cost = def.cost;
    final canAfford = !owned && sc.wallet >= cost;

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A0B18).withValues(alpha: 0.6),
        border: Border.all(
          color: owned
              ? const Color(0xFFFFD700).withValues(alpha: 0.8)
              : _crimson.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _crimson.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: _crimson.withValues(alpha: 0.6)),
                ),
                child: Text(
                  def.icon,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Static combo-key preview strip.
                    if (def.combo.isNotEmpty)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _ComboStrip(combo: def.combo),
                      )
                    else
                      Text(
                        def.comboLabel.toUpperCase(),
                        style: TextStyle(
                          color: _crimson,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                  ],
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (owned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'OWNED',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: canAfford
                      ? () => SkillController.instance.purchase(def.id)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAfford ? _crimson : null,
                    foregroundColor: canAfford ? Colors.black : Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    '${canAfford ? 'BUY ' : ''}$cost◆',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A static preview of a legendary combo: each action is a key pill shown in
/// sequence order.
class _ComboStrip extends StatelessWidget {
  final List<ComboAction> combo;

  const _ComboStrip({required this.combo});

  String _label(ComboAction a) {
    switch (a) {
      case ComboAction.jump:
        return 'JUMP';
      case ComboAction.smash:
        return 'ATTACK';
      case ComboAction.crawl:
        return 'CRAWL';
    }
  }

  String _glyph(ComboAction a) {
    switch (a) {
      case ComboAction.jump:
        return '▲';
      case ComboAction.smash:
        return '★';
      case ComboAction.crawl:
        return '▼';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < combo.length; i++) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Text('·', style: TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.w900))),
          _ComboKey(
            glyph: _glyph(combo[i]),
            label: _label(combo[i]),
            color: const Color(0xFFFF5C8A),
          ),
        ],
      ],
    );
  }
}

class _ComboKey extends StatelessWidget {
  final String glyph;
  final String label;
  final Color color;

  const _ComboKey({
    required this.glyph,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            glyph,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}