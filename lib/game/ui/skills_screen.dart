import 'dart:async';

import 'package:flutter/material.dart';

import '../settings/legendary_defs.dart';
import '../settings/skill_controller.dart';
import '../settings/skill_defs.dart';
import 'stickman_avatar.dart';

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

  /// Scroll controller for the legendary list so the empty slot shop
  /// affordance can scroll the unowned cards into view.
  final ScrollController _legendaryScroll = ScrollController();

  /// One GlobalKey per legendary definition, used to reveal an unowned card
  /// when an empty slot is tapped.
  final Map<LegendarySkill, GlobalKey> _legendaryCardKeys = {};

  GlobalKey _cardKeyFor(LegendarySkill id) =>
      _legendaryCardKeys.putIfAbsent(id, GlobalKey.new);

  /// The legendary card currently flashing after an empty slot tap, used to
  /// give visible feedback even when the revealed card is already on screen.
  LegendarySkill? _highlightedLegendary;

  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _legendaryScroll.dispose();
    super.dispose();
  }

  /// Scrolls the legendary shop list so the card for [id] is in view.
  void _revealLegendaryCard(LegendarySkill id) {
    final context = _legendaryCardKeys[id]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
  }

  /// Briefly pulses the shop card for [id] so the player can spot it, even
  /// when the card is already fully visible and no scrolling is needed.
  void _flashLegendary(LegendarySkill id) {
    setState(() => _highlightedLegendary = id);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightedLegendary = null);
    });
  }

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
                            color: Colors.yellow,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.2,
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
                                    onTap: () => setState(() => _activeTab = 0),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _TabChip(
                                    label: '★ LEGENDARY',
                                    active: _activeTab == 1,
                                    color: _crimson,
                                    onTap: () => setState(() => _activeTab = 1),
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
        ..._pairs([
          for (final def in SkillDef.all) _SkillCard(def: def),
        ], minCardHeight: 168),
      ],
    );
  }

  /// Chunks a list of cards into rows of two so the grid gains vertical space.
  /// A lone leftover card keeps the width of a single grid cell (half-width,
  /// never stretched across the whole row).
  List<Widget> _pairs(List<Widget> cards, {double minCardHeight = 0}) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      final hasSecond = i + 1 < cards.length;
      rows.add(
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = hasSecond
                ? null
                : (constraints.maxWidth - 12) / 2;
            Widget row = Row(
              crossAxisAlignment: minCardHeight > 0
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
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
            if (minCardHeight > 0) {
              row = IntrinsicHeight(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minCardHeight),
                  child: row,
                ),
              );
            }
            return row;
          },
        ),
      );
      rows.add(const SizedBox(height: 12));
    }
    return rows;
  }

  Widget _buildLegendary(SkillController sc) {
    final firstUnowned = LegendaryDef.all
        .map((d) => d.id)
        .where((id) => !sc.owned.contains(id))
        .firstOrNull;
    return ListView(
      controller: _legendaryScroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Active legendary loadout: stickman avatar on the left, the two
        // equip slots on the right.
        _LegendaryLoadoutSection(
          sc: sc,
          onEmptySlotTap: firstUnowned == null
              ? null
              : () {
                  _revealLegendaryCard(firstUnowned);
                  _flashLegendary(firstUnowned);
                },
        ),
        const SizedBox(height: 6),
        Text(
          'Own every legendary permanently — equip any ${SkillController.maxLegendaries} '
          'for your next run. Equipping is free.',
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        ..._pairs([
          for (final def in LegendaryDef.all)
            _LegendaryCard(
              key: _cardKeyFor(def.id),
              def: def,
              highlighted: def.id == _highlightedLegendary,
            ),
        ], minCardHeight: 168),
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

/// A labelled + priced action button (UPGRADE / BUY). Tapping it shows a brief
/// modal loading dialog while [onAction] runs — held for a minimum of ~1s so
/// the player can see the purchase/upgrade is being processed — then runs
/// [onSuccess] (e.g. a confirmation modal) on success.
///
/// The loading dialog is pushed through a captured [NavigatorState] so it stays
/// visible even if this button is replaced by a rebuild while the action runs
/// (buying a legendary immediately flips the card to an EQUIP/ACTIVE state).
class _AsyncActionButton extends StatelessWidget {
  final String label;
  final int cost;
  final Color accent;
  final bool enabled;
  final Future<bool> Function() onAction;
  final Future<void> Function()? onSuccess;

  const _AsyncActionButton({
    required this.label,
    required this.cost,
    required this.accent,
    required this.enabled,
    required this.onAction,
    this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled
          ? () {
              final navigator = Navigator.of(context);
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const _ProcessingDialog(),
              );
              _perform(navigator);
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? accent : null,
        foregroundColor: enabled ? Colors.black : Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        '${enabled ? '$label ' : ''}$cost◆',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  Future<void> _perform(NavigatorState navigator) async {
    // Hold the loading dialog for at least a second so it is clearly visible.
    final minHold = Future<void>.delayed(const Duration(seconds: 1));
    bool ok;
    try {
      ok = await onAction();
    } finally {
      await minHold;
    }
    if (navigator.canPop()) navigator.pop(); // close the loading dialog
    if (ok && onSuccess != null) {
      await onSuccess!();
    }
  }
}

/// Full-screen loading dialog shown while a purchase/upgrade is processed.
class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFFFFD700),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'PROCESSING…',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
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
                _AsyncActionButton(
                  label: 'UPGRADE',
                  cost: cost,
                  accent: accent,
                  enabled: canAfford,
                  onAction: () => SkillController.instance.upgrade(def.id),
                  onSuccess: () async {
                    if (!context.mounted) return;
                    final tier = SkillController.instance.tierOf(def.id);
                    await _showSuccessModal(
                      context,
                      icon: def.icon,
                      title: 'UPGRADED!',
                      message: '${def.name} is now Tier $tier.',
                      accent: accent,
                    );
                  },
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

class _LegendaryCard extends StatelessWidget {
  final LegendaryDef def;

  /// When true this card is the one revealed by an empty-slot tap and gets a
  /// brief glow/scale pulse until the highlight timer clears it.
  final bool highlighted;

  static const Color _crimson = Color(0xFFFF5C8A);

  const _LegendaryCard({
    super.key,
    required this.def,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final sc = SkillController.instance;
    final owned = sc.hasLegendary(def.id);
    final equipped = sc.isActive(def.id);
    final cost = def.cost;
    final canAfford = !owned && sc.wallet >= cost;

    final Color borderColor = highlighted
        ? _crimson
        : equipped
        ? const Color(0xFFFFD700).withValues(alpha: 0.8)
        : _crimson.withValues(alpha: 0.5);

    final Widget card = Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A0B18).withValues(alpha: 0.6),
        border: Border.all(color: borderColor, width: highlighted ? 2.4 : 1.2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: _crimson.withValues(alpha: 0.6),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
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
              if (highlighted)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _crimson,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SHOP ★',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (owned)
                equipped
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => _equipLegendaryFromCard(context, def),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _crimson,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'EQUIP',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      )
              else
                _AsyncActionButton(
                  label: 'BUY',
                  cost: cost,
                  accent: _crimson,
                  enabled: canAfford,
                  onAction: () => SkillController.instance.purchase(def.id),
                  onSuccess: () async {
                    if (!context.mounted) return;
                    await _showSuccessModal(
                      context,
                      icon: def.icon,
                      title: 'OWNED!',
                      message:
                          'Bought ${def.name} for $cost◆ — '
                          'equip it to use it in your next run.',
                      accent: _crimson,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );

    if (!highlighted) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.05),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: card,
    );
  }
}

/// Equips an owned-but-unequipped legendary [def] into a slot, for free. When
/// both slots are busy the player first picks which active skill to evict.
Future<void> _equipLegendaryFromCard(
  BuildContext context,
  LegendaryDef def,
) async {
  final sc = SkillController.instance;
  LegendarySkill? replaced;
  if (sc.activeSlotsFull) {
    replaced = await showDialog<LegendarySkill>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EquipReplaceDialog(incoming: def),
    );
    if (replaced == null || !context.mounted) return;
  }
  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ProcessingDialog(),
  );
  final ok = await sc.equipLegendary(def.id, replaced: replaced);
  await Future<void>.delayed(const Duration(seconds: 1));
  if (navigator.canPop()) navigator.pop();
  if (!ok || !context.mounted) return;
  await _showSuccessModal(
    context,
    icon: def.icon,
    title: 'EQUIPPED!',
    message: '${def.name} equipped — free, ready for your next run.',
    accent: const Color(0xFFFF5C8A),
  );
}

/// Shows a detail dialog for an equipped legendary [def]. When the player
/// removes it, the skill is unequipped and a success modal is shown.
Future<void> _openLegendaryInfoDialog(
  BuildContext context,
  LegendaryDef def,
) async {
  final removed = await showDialog<bool>(
    context: context,
    builder: (_) => _LegendaryInfoDialog(def: def),
  );
  if (removed != true || !context.mounted) return;
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ProcessingDialog(),
  );
  await SkillController.instance.unequipLegendary(def.id);
  await Future<void>.delayed(const Duration(seconds: 1));
  if (navigator.canPop()) navigator.pop();
  if (!context.mounted) return;
  await _showSuccessModal(
    context,
    icon: def.icon,
    title: 'REMOVED!',
    message:
        '${def.name} was removed from your active loadout — it stays in '
        'your collection and can be re-equipped for free.',
    accent: const Color(0xFFFF5C8A),
  );
}

/// Cinematic success dialog shown after a skill purchase or upgrade completes:
/// a glowing badge, a headline, the outcome text and a single DONE button.
/// The player must acknowledge it before the screen is interactive again.
Future<void> _showSuccessModal(
  BuildContext context, {
  required String icon,
  required String title,
  required String message,
  required Color accent,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                icon,
                style: TextStyle(
                  color: accent,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Header loadout shown at the top of the LEGENDARY tab: a stickman avatar on
/// the left, and the two active legendary equip slots on the right. Each slot
/// is either the equipped legendary (tapped for info) or a dashed empty
/// placeholder (tapped to jump to a purchasable card below).
class _LegendaryLoadoutSection extends StatelessWidget {
  final SkillController sc;
  final VoidCallback? onEmptySlotTap;

  const _LegendaryLoadoutSection({required this.sc, this.onEmptySlotTap});

  @override
  Widget build(BuildContext context) {
    final active = [
      for (final def in LegendaryDef.all)
        if (sc.isActive(def.id)) def,
    ];
    final maxSlots = SkillController.maxLegendaries;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5C8A).withValues(alpha: 0.08),
        border: Border.all(
          color: const Color(0xFFFF5C8A).withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const StickmanAvatar(size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACTIVE LEGENDARIES',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < maxSlots; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _LegendarySlot(
                            def: i < active.length ? active[i] : null,
                            onTap: i < active.length
                                ? () => _openLegendaryInfoDialog(
                                    context,
                                    active[i],
                                  )
                                : onEmptySlotTap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One slot in the legendary loadout: either the equipped legendary ([def]
/// set, tapped to show info) or a dashed empty placeholder ([def] null).
class _LegendarySlot extends StatelessWidget {
  final LegendaryDef? def;
  final VoidCallback? onTap;

  const _LegendarySlot({required this.def, this.onTap});

  @override
  Widget build(BuildContext context) {
    final filled = def != null;
    final foreground = filled ? const Color(0xFFFFD700) : Colors.white;

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        filled
            ? Text(
                def!.icon,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              )
            : Icon(
                Icons.add_circle_outline,
                color: Colors.white.withValues(alpha: 0.35),
                size: 18,
              ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            filled ? def!.name : 'EMPTY',
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 3),
        if (filled)
          Text(
            'TAP FOR INFO',
            style: TextStyle(
              color: foreground.withValues(alpha: 0.5),
              fontSize: 7,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: filled
            ? BoxDecoration(
                color: const Color(0xFFFF5C8A).withValues(alpha: 0.14),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.7),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: filled
            ? content
            : CustomPaint(
                foregroundPainter: _DashedBorderPainter(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                // Fill the stretched slot height so the empty placeholder is
                // exactly as tall as the filled slot beside it.
                size: Size.infinite,
                child: Center(
                  child: Padding(
                    // Extra vertical breathing room inside the empty
                    // placeholder so it doesn't look cramped top/bottom.
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    child: content,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Paints a rounded dashed border used by the empty legendary slot.
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      );

    const dashWidth = 5.0;
    const dashSpace = 3.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Detail dialog for an equipped legendary: shows its icon, name, trigger
/// combo, description and cost, plus a REMOVE action that unequips it from
/// the active loadout (it stays in the collection).
class _LegendaryInfoDialog extends StatelessWidget {
  final LegendaryDef def;

  const _LegendaryInfoDialog({required this.def});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E0A12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFFF5C8A), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5C8A).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF5C8A).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    def.icon,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    def.name,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (def.combo.isNotEmpty) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _ComboStrip(combo: def.combo),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              def.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${def.cost}◆ to buy · equipped & ready for your next run',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  label: const Text(
                    'REMOVE',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C8A),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog asking which currently equipped legendary to put away so a newly
/// equipped one can take its slot. Tapping an option returns that skill's id.
class _EquipReplaceDialog extends StatelessWidget {
  final LegendaryDef incoming;

  const _EquipReplaceDialog({required this.incoming});

  @override
  Widget build(BuildContext context) {
    final sc = SkillController.instance;
    final activeDefs = [
      for (final def in LegendaryDef.all)
        if (sc.isActive(def.id)) def,
    ];

    return Dialog(
      backgroundColor: const Color(0xFF1E0A12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFFF5C8A), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REPLACE ACTIVE SKILL',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Equip ${incoming.name} for free. Pick which active skill "
              'to put away — it stays in your collection.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            for (final def in activeDefs)
              GestureDetector(
                onTap: () => Navigator.of(context).pop(def.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5C8A).withValues(alpha: 0.18),
                    border: Border.all(
                      color: const Color(0xFFFF5C8A),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        def.icon,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          def.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'CANCEL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                '·',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
        ],
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
