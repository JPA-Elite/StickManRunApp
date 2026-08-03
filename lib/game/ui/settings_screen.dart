import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/game_settings.dart';
import '../settings/settings_controller.dart';

/// Arcade-Console style settings screen.
///
/// Panels use the game's visual language: black + dark panel fills, yellow
/// 2px borders, monospace section headers, chunky lever switches and
/// segmented controls with a glowing active segment.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: SettingsController.instance,
            builder: (context, _) {
              final settings = SettingsController.instance.settings;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsPanel(
                      title: 'GAMEPLAY',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingRow(
                            label: 'DIFFICULTY',
                            control: _SegmentGroup<GameDifficulty>(
                              options: GameDifficulty.values,
                              selected: settings.difficulty,
                              labelOf: (d) => d.label,
                              onSelected: SettingsController.instance
                                  .setDifficulty,
                            ),
                          ),
                          const _RowDivider(),
                          _SettingRow(
                            label: 'CONTROLS',
                            control: _SegmentGroup<ControlScheme>(
                              options: ControlScheme.values,
                              selected:
                                  settings.controlScheme ?? ControlScheme.buttons,
                              labelOf: (s) => s.label,
                              onSelected: SettingsController.instance
                                  .setControlScheme,
                            ),
                          ),
                           const _RowDivider(),
                           _SettingRow(
                             label: 'VIBRATIONS',
                             control: _ArcadeSwitch(
                               value: settings.vibrationsEnabled,
                               onChanged: (value) {
                                 if (value) {
                                   HapticFeedback.mediumImpact();
                                 }
                                 SettingsController.instance
                                     .setVibrationsEnabled(value);
                               },
                             ),
                           ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingsPanel(
                      title: 'APPEARANCE',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingRow(
                            label: 'STICKMAN COLOR',
                            control: _StickmanColorPicker(
                              selected: settings.stickmanColor,
                              onSelected: SettingsController.instance
                                  .setStickmanColor,
                            ),
                          ),
                          const _RowDivider(),
                          _SettingRow(
                            label: 'COIN SIZE',
                            control: _SegmentGroup<CoinSize>(
                              options: CoinSize.values,
                              selected: settings.coinSize,
                              labelOf: (s) => s.label,
                              onSelected: SettingsController.instance
                                  .setCoinSize,
                            ),
                          ),
                          const _RowDivider(),
                          _SettingRow(
                            label: 'HIGH-CONTRAST OUTLINES',
                            control: _ArcadeSwitch(
                              value: settings.highContrast,
                              onChanged: SettingsController.instance
                                  .setHighContrast,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingsPanel(
                      title: 'DATA',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: _ArcadeResetButton(
                          onPressed: () => _confirmReset(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingsPanel(
                      title: 'INFO',
                      child: Column(
                        children: [
                          _InfoRow(
                            label: 'ABOUT',
                            onTap: () => _showAbout(context),
                          ),
                          _InfoRow(
                            label: 'PRIVACY POLICY',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GameInfoScreen(
                                  title: 'PRIVACY POLICY',
                                  body: _privacyBody,
                                ),
                              ),
                            ),
                          ),
                          _InfoRow(
                            label: 'TERMS OF USE',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GameInfoScreen(
                                  title: 'TERMS OF USE',
                                  body: _termsBody,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111318),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.yellow, width: 2),
        ),
        title: const Text(
          'RESET SETTINGS?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        content: const Text(
          'All settings will be restored to their defaults.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              SettingsController.instance.reset();
              Navigator.of(dialogContext).pop();
            },
            child: const Text(
              'RESET',
               style: TextStyle(
                 color: Colors.white,
                 fontWeight: FontWeight.w900,
               ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameInfoScreen(
          title: 'ABOUT',
          body: _aboutBody,
        ),
      ),
     );
   }
 }

  const String _aboutBody =
      'Stickman Run is a fast-paced arcade runner where you guide a '
      'stick figure through increasingly challenging levels packed with '
      'obstacles, coins, and power-ups.\n\n'
      '▸ Jump over ground obstacles by tapping the JUMP button.\n'
      '▸ Crawl under high obstacles by tapping the CRAWL button.\n'
      '▸ Smash obstacles with the SMASH button when they are close.\n'
      '▸ Collect coins for points and grab shield/magnet boosts.\n'
      '▸ Survive as long as you can — the difficulty scales up over time.\n\n'
      'Controls:\n'
      '▸ BUTTONS mode — use the on-screen JUMP, CRAWL, and SMASH buttons.\n'
      '▸ GESTURES mode — swipe up to jump, swipe down to crawl, tap to smash.';

  const String _privacyBody =
      'Stickman Run does not collect, store or share any personal data. All '
      'game progress and settings are stored locally on your device only.\n\n'
      'No analytics, no ads, no third-party trackers are included in this game.';

  const String _termsBody =
      'By playing Stickman Run you agree to enjoy it responsibly. The game is '
      'provided as-is for entertainment purposes only.\n\n'
      'All game assets, code and content belong to the game developers. '
      'You may not resell or redistribute the game without permission.';

/// Reusable lightweight full-screen info page for Privacy/Terms.
class GameInfoScreen extends StatelessWidget {
  final String title;
  final String body;

  const GameInfoScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              body,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bordered panel with a monospace yellow header (the "console" look).
class _SettingsPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        border: Border.all(color: Colors.yellow, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Label on the left, control on the right, minimum 44px tall touch target.
class _SettingRow extends StatelessWidget {
  final String label;
  final Widget control;

  const _SettingRow({required this.label, required this.control});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          control,
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: Colors.white12, height: 1),
    );
  }
}

/// Yellow 3-segment control with the active segment filled yellow.
class _SegmentGroup<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  const _SegmentGroup({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.yellow, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            _SegmentButton<T>(
              option: options[i],
              label: labelOf(options[i]),
              active: options[i] == selected,
              onTap: () => onSelected(options[i]),
              showLeftBorder: i > 0,
            ),
        ],
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  final T option;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool showLeftBorder;

  const _SegmentButton({
    required this.option,
    required this.label,
    required this.active,
    required this.onTap,
    required this.showLeftBorder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        constraints: const BoxConstraints(minWidth: 68),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.yellow : Colors.transparent,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.35),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : null,
          border: showLeftBorder
              ? const Border(
                  left: BorderSide(color: Colors.black, width: 2),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Thick lever-style toggle: yellow track + white knob when on.
class _ArcadeSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ArcadeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 32,
        decoration: BoxDecoration(
          color: value ? Colors.yellow : const Color(0xFF111318),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? Colors.yellow : Colors.white,
            width: 2,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four color swatches; each shows a mini stickman preview in that color.
class _StickmanColorPicker extends StatelessWidget {
  static const List<int> _swatches = [
    0xFFFFFFFF, // white
    0xFFFFFF00, // yellow
    0xFF00FFFF, // cyan
    0xFFFF4C4C, // red
  ];

  final int selected;
  final ValueChanged<int> onSelected;

  const _StickmanColorPicker({
    required this.selected,
    required this.onSelected,
  });

  static Color _iconColorFor(int swatch) {
    final c = Color(swatch);
    final luminance =
        (0.299 * c.red + 0.587 * c.green + 0.114 * c.blue) / 255.0;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in _swatches)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () => onSelected(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(color),
                  border: Border.all(
                    color: color == selected ? Colors.yellow : Colors.black,
                    width: color == selected ? 3 : 2,
                  ),
                  boxShadow: color == selected
                      ? [
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: _StickmanIcon(
                    color: _iconColorFor(color),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tiny stickman glyph used to preview a color swatch.
class _StickmanIcon extends StatelessWidget {
  final Color color;

  const _StickmanIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 26),
      painter: _StickmanIconPainter(color: color),
    );
  }
}

class _StickmanIconPainter extends CustomPainter {
  final Color color;

  const _StickmanIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final bottom = size.height;

    canvas.drawCircle(Offset(cx, size.height * 0.16), size.width * 0.2, paint);

    final torsoY = size.height * 0.34;
    final hipY = size.height * 0.68;
    canvas.drawLine(Offset(cx, torsoY), Offset(cx, hipY), paint);

    canvas.drawLine(
      Offset(cx, torsoY),
      Offset(cx - size.width * 0.42, size.height * 0.52),
      paint,
    );
    canvas.drawLine(
      Offset(cx, torsoY),
      Offset(cx + size.width * 0.42, size.height * 0.52),
      paint,
    );

    canvas.drawLine(
      Offset(cx, hipY),
      Offset(cx - size.width * 0.32, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(cx, hipY),
      Offset(cx + size.width * 0.32, bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StickmanIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ArcadeResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ArcadeResetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.yellow,
          side: const BorderSide(color: Colors.yellow, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        child: const Text('RESET SETTINGS'),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _InfoRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
          ],
        ),
      ),
    );
  }
}
