import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../settings/shop.dart';
import '../settings/skill_controller.dart';

/// Coin shop page: a one-time welcome bonus plus purchasable coin packs.
/// Real purchases are not wired up yet — tapping a pack shows a
/// "COMING SOON" dialog.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const Color _gold = Color(0xFFFFD700);

  /// Drives the pack showcase carousel, mirroring the level-select pager.
  late final PageController _pageController = PageController(
    viewportFraction: 0.68,
  );
  int _activePack = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _claimBonus() async {
    final controller = ShopController.instance;
    final ok = await controller.claimBonus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Welcome bonus claimed: +${ShopController.welcomeBonusCoins}◆!' : 'Bonus already claimed.',
        ),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  /// Shows the COMING SOON dialog; resolves once the player dismisses it
  /// so the calling card can play its chest-close animation.
  Future<void> _showComingSoon(CoinPack pack) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111318),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _gold, width: 2),
        ),
        title: const Text(
          'COMING SOON',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _gold,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          'Buying ${pack.coins}◆ for ₱${pack.pesos} is on its way.\nIn the meantime, keep collecting coins in-game!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                      'SHOP',
                      style: TextStyle(
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
                    builder: (context, _) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _gold.withValues(alpha: 0.45),
                        ),
                        color: Colors.white.withValues(alpha: 0.06),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _gold.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.03),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: _gold,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            formatCoinAmount(
                              SkillController.instance.wallet,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.yellow, height: 1),
            Expanded(
              child: ListenableBuilder(
                listenable: ShopController.instance,
                builder: (context, _) {
                  final bonusClaimed =
                      ShopController.instance.bonusClaimed;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Welcome bonus card (claimable once).
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _gold,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _gold.withValues(alpha: 0.18),
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.card_giftcard,
                                color: _gold,
                                size: 44,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'WELCOME BONUS',
                                style: TextStyle(
                                  color: _gold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '+${ShopController.welcomeBonusCoins}◆',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 30,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bonusClaimed
                                    ? 'Bonus claimed — thank you for playing!'
                                    : 'Claim your one-time coin bonus to boost your wallet.',
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: bonusClaimed ? null : _claimBonus,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: bonusClaimed
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : _gold,
                                    foregroundColor: Colors.black,
                                    disabledForegroundColor: Colors.white
                                        .withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    bonusClaimed ? 'CLAIMED' : 'CLAIM BONUS',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Coin packs section header.
                        Row(
                          children: [
                            const Icon(
                              Icons.shopping_bag,
                              color: _gold,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'COIN PACKS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Pack showcase carousel: the active pack scales up
                        // with a gold border while neighbors recede, exactly
                        // like the level-select pager on the home screen.
                        SizedBox(
                          height: 300,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: CoinPack.all.length,
                            onPageChanged: (index) =>
                                setState(() => _activePack = index),
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: _ShowcaseCard(
                                pack: CoinPack.all[index],
                                active: index == _activePack,
                                onTap: () =>
                                    _showComingSoon(CoinPack.all[index]),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Dot indicator, matching the carousel position.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < CoinPack.all.length; i++)
                              AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: i == _activePack ? 18 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: i == _activePack
                                      ? _gold
                                      : Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                          ],
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

/// One pack in the showcase carousel. The active card scales up with a gold
/// border and glow while neighbors recede — mirroring the level-select pager
/// on the home screen. The card carries a tier-colored gradient backdrop, a
/// glowing chest with twinkling sparkles, and a shimmer sweep on the active
/// card. Tapping shows the "COMING SOON" dialog.
class _ShowcaseCard extends StatefulWidget {
  final CoinPack pack;
  final bool active;

  /// Invoked after the chest finishes opening; must complete (e.g. after the
  /// COMING SOON modal is dismissed) so the chest can cinematically close.
  final Future<void> Function() onTap;

  const _ShowcaseCard({
    required this.pack,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ShowcaseCard> createState() => _ShowcaseCardState();
}

class _ShowcaseCardState extends State<_ShowcaseCard>
    with TickerProviderStateMixin {
  /// Drives the sparkle twinkle on the chest artwork.
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  /// One-shot cinematic splash, replayed whenever the card becomes active.
  late final AnimationController _splash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  /// One-shot chest-open animation, replayed whenever the card is tapped
  /// (including the BUY button). The COMING SOON modal appears only after
  /// this finishes.
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  static const Color _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _splash.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant _ShowcaseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _splash.forward(from: 0);
    }
    // Close the chest again once the card is no longer focused, so returning
    // to it starts from a sealed chest.
    if (!widget.active && oldWidget.active) {
      _open.value = 0;
    }
  }

  /// Plays the cinematic chest-open. The COMING SOON modal appears as soon
  /// as the lid has swung at least 90° (the lid rotates -o * 1.9 rad, so 90°
  /// is reached at o = pi/2 / 1.9), while the chest keeps opening behind it;
  /// once the modal is dismissed the chest cinematically closes again.
  Future<void> _handleBuy() async {
    if (_open.isAnimating) return;

    // Lid rotation in radians at a 90° swing: -o * 1.9 = -pi/2.
    final threshold = (pi / 2) / 1.9;
    final ready = Completer<void>();
    void onTick() {
      if (!ready.isCompleted && _open.value >= threshold) {
        ready.complete();
      }
    }

    _open.addListener(onTick);
    onTick();
    // Fire-and-forget: the chest keeps swinging fully open behind the modal.
    unawaited(_open.forward(from: 0));
    await ready.future;
    _open.removeListener(onTick);
    if (!mounted) return;
    await widget.onTap();
    if (!mounted) return;
    // Modal dismissed — seal the chest back up with the same animation,
    // reversed.
    await _open.reverse();
  }

  @override
  void dispose() {
    _fx.dispose();
    _splash.dispose();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = CoinPack.all.indexOf(widget.pack);
    final tier = _ChestTier.all[index.clamp(0, _ChestTier.all.length - 1)];
    final active = widget.active;

    return AnimatedScale(
      scale: active ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: _handleBuy,
        child: AnimatedBuilder(
          // Rebuilds for the sparkle twinkle (fx) and the chest-open (open).
          animation: Listenable.merge([_fx, _open]),
          builder: (context, _) {
            final t = _fx.value;
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active
                      ? _gold
                      : tier.accent.withValues(alpha: 0.55),
                  width: active ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (active ? _gold : tier.accent).withValues(
                      alpha: active ? 0.35 : 0.14,
                    ),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tier.accent.withValues(alpha: 0.32),
                    const Color(0xFF0C0F14),
                    const Color(0xFF0C0F14),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Height reserved for the info block (badge/amount row +
                  // BUY button + padding) so the chest and BUY button can be
                  // sized from the same constraints below.
                  const infoH = 92.0;
                  final chestW = min(
                    constraints.maxWidth - 36,
                    (constraints.maxHeight - infoH - 28) / 0.72,
                  ).clamp(40.0, constraints.maxWidth - 36);

                  // Ribbon length long enough that, once rotated, both tips
                  // extend past the card edges and get clipped flush — so the
                  // banner looks fully connected to the top and left sides.
                  final ribbonLen = (constraints.maxWidth * 0.62)
                      .clamp(220.0, 420.0);

                  return Stack(
                fit: StackFit.expand,
                children: [
                  // Soft accent glow radiating behind the chest.
                  Align(
                    alignment: const Alignment(0, -0.2),
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            tier.accent.withValues(alpha: 0.4),
                            tier.accent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Cinematic splash: an expanding gold ring + flash that
                  // plays once whenever this card becomes active.
                  if (active)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _splash,
                          builder: (context, _) {
                            final p = _splash.value;
                            return CustomPaint(
                              painter: _SplashPainter(
                                progress: p,
                                accent: _gold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Treasure-chest artwork, centered in its area and
                      // sized from the shared [chestW] so it lines up with
                      // the BUY button width below.
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                          // Slightly toward the top of the artwork zone so it
                          // balances against the info block below.
                          child: Align(
                            alignment: const Alignment(0, -0.12),
                            child: CustomPaint(
                              size: Size(chestW, chestW * 0.72),
                              painter: _ChestPainter(
                                body: tier.body,
                                lid: tier.lid,
                                band: tier.band,
                                gem: tier.gem,
                                glow: tier.accent,
                                sparklePhase: t,
                                open: _open.value,
                                scale: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Centered metallic gold-gradient coin amount.
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.monetization_on,
                                    color: _gold,
                                    size: 28,
                                    shadows: [
                                      Shadow(
                                        color: _gold.withValues(alpha: 0.8),
                                        blurRadius: 14,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 6),
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFFFFF8DC),
                                            Color(0xFFFFD700),
                                            Color(0xFFB8860B),
                                          ],
                                          stops: [0.0, 0.55, 1.0],
                                        ).createShader(bounds),
                                    blendMode: BlendMode.srcIn,
                                    child: Text(
                                      '+${formatCoinAmount(widget.pack.coins)}◆',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 28,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // BUY button with the peso price inside, centered
                            // at the same width as the chest above it.
                            Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: chestW,
                                child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: tier.accent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: tier.accent.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'BUY',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '₱${widget.pack.pesos}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Tier ribbon in the top-left corner, styled like the BEST
                  // VALUE ribbon (rotated accent banner). The band is long
                  // enough that its rotated tips poke past the card edges and
                  // are clipped flush, so it reads as fully connected to the
                  // top and left sides of the card.
                  Positioned(
                    top: 12,
                    left: -ribbonLen * 0.5 + 30,
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Container(
                        width: ribbonLen,
                        height: 26,
                        decoration: BoxDecoration(
                          color: tier.accent,
                          boxShadow: [
                            BoxShadow(
                              color: tier.accent.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tier.icon, color: Colors.black, size: 12),
                            const SizedBox(width: 5),
                            Text(
                              tier.name,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // BEST VALUE ribbon pinned to the vault pack's top-right.
                  if (index == CoinPack.all.length - 1)
                    Positioned(
                      top: 12,
                      right: -34,
                      child: Transform.rotate(
                        angle: 0.5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 34,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _gold,
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Text(
                            'BEST VALUE',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One treasure-chest tier: escalating materials + colors, plus a visual
/// scale so pricier chests look bigger.
class _ChestTier {
  final String name;
  final Color accent;
  final Color body;
  final Color lid;
  final Color band;

  /// Icon shown on the tier medallion badge.
  final IconData icon;

  /// Gem color drawn on the lock, or null for tiers without gems.
  final Color? gem;

  /// Size multiplier for the chest artwork (1.0 = wooden, up to 1.35 vault).
  final double scale;

  const _ChestTier({
    required this.name,
    required this.accent,
    required this.body,
    required this.lid,
    required this.band,
    required this.icon,
    this.gem,
    this.scale = 1.0,
  });

  static const List<_ChestTier> all = [
    _ChestTier(
      name: 'WOODEN',
      accent: Color(0xFFB87333),
      body: Color(0xFF8B5A2B),
      lid: Color(0xFF6E4423),
      band: Color(0xFF3E2A12),
      icon: Icons.park,
      scale: 1.0,
    ),
    _ChestTier(
      name: 'STEEL',
      accent: Color(0xFFB0BEC5),
      body: Color(0xFF78909C),
      lid: Color(0xFF607D8B),
      band: Color(0xFF37474F),
      icon: Icons.shield,
      scale: 1.06,
    ),
    _ChestTier(
      name: 'SILVER',
      accent: Color(0xFFE0E0E0),
      body: Color(0xFFCFD8DC),
      lid: Color(0xFFB0BEC5),
      band: Color(0xFF78909C),
      icon: Icons.star,
      scale: 1.12,
    ),
    _ChestTier(
      name: 'GOLD',
      accent: Color(0xFFFFD700),
      body: Color(0xFFF5C518),
      lid: Color(0xFFD4A017),
      band: Color(0xFF8B6914),
      icon: Icons.workspace_premium,
      scale: 1.18,
    ),
    _ChestTier(
      name: 'JEWELED',
      accent: Color(0xFF7DF9FF),
      body: Color(0xFFF5C518),
      lid: Color(0xFFD4A017),
      band: Color(0xFF8B6914),
      icon: Icons.diamond,
      gem: Color(0xFFE53935),
      scale: 1.26,
    ),
    _ChestTier(
      name: 'VAULT',
      accent: Color(0xFF9B5DE5),
      body: Color(0xFF263238),
      lid: Color(0xFF37474F),
      band: Color(0xFFFFD700),
      icon: Icons.emoji_events,
      gem: Color(0xFF00E5FF),
      scale: 1.35,
    ),
  ];
}

/// Draws a stylized treasure chest: a rounded body with a curved lid, metal
/// bands, a central lock, gold coins spilling out the front, a soft accent
/// glow behind it, a ground shadow beneath, and twinkling sparkles. The chest
/// is sized to fit the available bounds (width or height), so it never gets
/// clipped inside wide carousel cards.
class _ChestPainter extends CustomPainter {
  final Color body;
  final Color lid;
  final Color band;
  final Color? gem;

  /// Accent color used for the backdrop glow + sparkle tint.
  final Color glow;

  /// 0..1 phase driving the sparkle twinkle.
  final double sparklePhase;

  /// 0..1 chest-open progress: the lid swings up on its hinge, an interior
  /// glow and light beam appear, and coins burst out of the opening.
  final double open;
  final double scale;

  const _ChestPainter({
    required this.body,
    required this.lid,
    required this.band,
    required this.gem,
    required this.glow,
    required this.sparklePhase,
    required this.open,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fit the chest inside the available box: it spans ~s wide and ~0.72s
    // tall, so the max scale is min(w, h / 0.72). The tier scale then grows
    // it within that bound.
    final fit = min(w, h / 0.72) * scale;
    final s = fit.clamp(0.0, min(w, h / 0.72));

    canvas.save();
    canvas.translate((w - s) / 2, (h - s * 0.72) / 2);

    // ---- Soft accent glow behind the chest. ----
    canvas.drawCircle(
      Offset(s * 0.5, s * 0.5),
      s * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.42),
            glow.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(s * 0.5, s * 0.5), radius: s * 0.62),
        ),
    );

    // ---- Ground shadow under the chest. ----
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.735),
        width: s * 0.56,
        height: s * 0.07,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // ---- Gold coins spilling out the front. ----
    void coin(double dx, double dy, double r, [double alpha = 1.0]) {
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: alpha),
      );
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()
          ..color = const Color(0xFFB8860B).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.012,
      );
    }

    coin(s * 0.30, s * 0.66, s * 0.055);
    coin(s * 0.44, s * 0.70, s * 0.05);
    coin(s * 0.62, s * 0.67, s * 0.058);
    coin(s * 0.74, s * 0.72, s * 0.046);

    // ---- Chest-open progress. ----
    final o = open.clamp(0.0, 1.0);

    // ---- Chest body. ----
    final bodyTop = s * 0.44;
    final bodyBottom = s * 0.72;
    final bodyLeft = s * 0.16;
    final bodyRight = s * 0.84;
    final bodyRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, bodyBottom),
      Radius.circular(s * 0.05),
    );
    canvas.drawRRect(bodyRRect, Paint()..color = body);

    // Vertical bands on the body.
    final bandPaint = Paint()..color = band;
    for (final bx in [0.34, 0.5, 0.66]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            s * bx - s * 0.028,
            bodyTop + s * 0.012,
            s * bx + s * 0.028,
            bodyBottom - s * 0.012,
          ),
          Radius.circular(s * 0.02),
        ),
        bandPaint,
      );
    }

    // ---- Interior glow + light beam while the chest opens. ----
    if (o > 0.02) {
      final opening = (o * 1.6).clamp(0.0, 1.0);

      // Glowing interior mouth at the top of the body.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            bodyLeft + s * 0.04,
            bodyTop - s * 0.01,
            bodyRight - s * 0.04,
            bodyTop + s * 0.12,
          ),
          Radius.circular(s * 0.03),
        ),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF3B0).withValues(alpha: 0.95 * opening),
              const Color(0xFFFFD700).withValues(alpha: 0.55 * opening),
              glow.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(s * 0.5, bodyTop),
              radius: s * 0.18,
            ),
          ),
      );

      // Rising beam of light from the opening.
      final beamH = s * 0.38 * opening;
      canvas.drawRect(
        Rect.fromLTRB(
          s * 0.36,
          bodyTop - beamH,
          s * 0.64,
          bodyTop + s * 0.06,
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFFFF8DC).withValues(alpha: 0.75 * opening),
              const Color(0xFFFFD700).withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTRB(
              s * 0.36,
              bodyTop - beamH,
              s * 0.64,
              bodyTop + s * 0.06,
            ),
          ),
      );
    }

    // ---- Curved lid, swinging up on its hinge as the chest opens. ----
    final lidTop = s * 0.26;
    final lidPath = Path()
      ..moveTo(bodyLeft, bodyTop)
      ..quadraticBezierTo(
        s * 0.5,
        lidTop - s * 0.06,
        bodyRight,
        bodyTop,
      )
      ..lineTo(bodyRight, bodyTop + s * 0.05)
      ..quadraticBezierTo(
        s * 0.5,
        bodyTop + s * 0.17,
        bodyLeft,
        bodyTop + s * 0.05,
      )
      ..close();

    if (o > 0.01) {
      // Hinge at the left back corner: rotate the lid up and back.
      canvas.save();
      canvas.translate(bodyLeft, bodyTop);
      canvas.rotate(-o * 1.9);
      canvas.translate(-bodyLeft, -bodyTop);
      canvas.drawPath(lidPath, Paint()..color = lid);

      // Lid band + lock travel with the lid.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            bodyLeft,
            bodyTop + s * 0.015,
            bodyRight,
            bodyTop + s * 0.075,
          ),
          Radius.circular(s * 0.02),
        ),
        bandPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            s * 0.5 - s * 0.055,
            bodyTop - s * 0.025,
            s * 0.5 + s * 0.055,
            bodyTop + s * 0.055,
          ),
          Radius.circular(s * 0.02),
        ),
        Paint()..color = band,
      );
      if (gem != null) {
        canvas.drawCircle(
          Offset(s * 0.5, bodyTop + s * 0.015),
          s * 0.028,
          Paint()..color = gem!,
        );
      }
      canvas.restore();
    } else {
      canvas.drawPath(lidPath, Paint()..color = lid);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            bodyLeft,
            bodyTop + s * 0.015,
            bodyRight,
            bodyTop + s * 0.075,
          ),
          Radius.circular(s * 0.02),
        ),
        bandPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            s * 0.5 - s * 0.055,
            bodyTop - s * 0.025,
            s * 0.5 + s * 0.055,
            bodyTop + s * 0.055,
          ),
          Radius.circular(s * 0.02),
        ),
        Paint()..color = band,
      );
      if (gem != null) {
        canvas.drawCircle(
          Offset(s * 0.5, bodyTop + s * 0.015),
          s * 0.028,
          Paint()..color = gem!,
        );
      }
    }

    // ---- Coins bursting out of the opening. ----
    if (o > 0.15) {
      final burst = ((o - 0.15) / 0.85).clamp(0.0, 1.0);
      final ease = Curves.easeOutCubic.transform(burst);
      final fade = (1.0 - burst).clamp(0.0, 1.0);
      final up = s * (0.16 + 0.42 * ease);
      final spread = s * 0.30 * ease;

      coin(s * 0.5, bodyTop - up, s * 0.045, 0.95 * fade);
      coin(
        s * 0.5 - spread * 0.6,
        bodyTop - up * 0.82,
        s * 0.038,
        0.9 * fade,
      );
      coin(
        s * 0.5 + spread * 0.6,
        bodyTop - up * 0.82,
        s * 0.038,
        0.9 * fade,
      );
      coin(
        s * 0.5 - spread,
        bodyTop - up * 0.5,
        s * 0.03,
        0.8 * fade,
      );
      coin(
        s * 0.5 + spread,
        bodyTop - up * 0.5,
        s * 0.03,
        0.8 * fade,
      );
    }

    // ---- Twinkling sparkles. ----
    final twinkle = Paint()
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round;
    void sparkle(double dx, double dy, double len, double phase) {
      final tw = 0.25 + 0.75 * (0.5 + 0.5 * sin(sparklePhase * 2 * pi + phase));
      twinkle.color = Colors.white.withValues(alpha: tw);
      canvas.drawLine(Offset(dx - len, dy), Offset(dx + len, dy), twinkle);
      canvas.drawLine(Offset(dx, dy - len), Offset(dx, dy + len), twinkle);
    }

    sparkle(s * 0.10, s * 0.34, s * 0.045, 0.0);
    sparkle(s * 0.90, s * 0.40, s * 0.05, 1.7);
    sparkle(s * 0.82, s * 0.18, s * 0.035, 3.4);
    sparkle(s * 0.16, s * 0.16, s * 0.04, 4.9);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChestPainter oldDelegate) =>
      oldDelegate.body != body ||
      oldDelegate.lid != lid ||
      oldDelegate.band != band ||
      oldDelegate.gem != gem ||
      oldDelegate.glow != glow ||
      oldDelegate.sparklePhase != sparklePhase ||
      oldDelegate.open != open ||
      oldDelegate.scale != scale;
}

/// Cinematic splash overlay drawn when a pack becomes active: an expanding
/// gold ring plus a soft white flash that swells from the center and fades
/// out as the ring reaches the card edges.
class _SplashPainter extends CustomPainter {
  final double progress;
  final Color accent;

  const _SplashPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress;
    if (p <= 0.0 || p >= 1.0) return;

    final center = size.center(Offset.zero);
    final maxR = size.longestSide * 0.75;
    final eased = Curves.easeOutCubic.transform(p);
    final radius = maxR * eased;
    final fade = (1.0 - p).clamp(0.0, 1.0);

    // Soft white flash swelling from the center.
    canvas.drawCircle(
      center,
      radius * 0.85,
      Paint()..color = Colors.white.withValues(alpha: 0.10 * fade),
    );

    // Expanding accent ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0 * fade + 0.5
        ..color = accent.withValues(alpha: 0.85 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _SplashPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
