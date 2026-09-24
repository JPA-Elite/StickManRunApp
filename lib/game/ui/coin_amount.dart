import 'package:flutter/material.dart';

/// Default gold for coin icons/amounts across shop, skills and profile.
const Color kCoinGold = Color(0xFFFFD700);

/// Dollar coin shown to the LEFT of an amount (replaces the old `◆` glyph).
class CoinIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CoinIcon({super.key, this.size = 14, this.color = kCoinGold});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.monetization_on, size: size, color: color);
  }
}

/// Standalone amount display: dollar icon + amount side by side.
/// Use for buttons, tiles and large prices.
class CoinAmount extends StatelessWidget {
  final String amount;
  final TextStyle? style;

  /// If null, the icon matches the text height exactly.
  final double? iconSize;
  final Color iconColor;
  final MainAxisAlignment alignment;

  const CoinAmount({
    super.key,
    required this.amount,
    this.style,
    this.iconSize,
    this.iconColor = kCoinGold,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final size = iconSize ?? style?.fontSize ?? 14;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CoinIcon(size: size, color: iconColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(amount, style: style),
        ),
      ],
    );
  }
}

/// Inline text where every `◆` marker renders as a dollar icon.
/// Use for full sentences (modal messages, captions).
class CoinText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// If null, the icon matches the text height exactly.
  final double? iconSize;
  final Color iconColor;

  const CoinText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.iconSize,
    this.iconColor = kCoinGold,
  });

  /// Matches an amount directly before a `◆` marker (e.g. `+20,000◆`,
  /// `1.5K◆`, `12.3M◆` — [formatCoinAmount] abbreviates large wallets).
  /// The icon is emitted BEFORE the amount so it always reads left-to-right
  /// as icon-then-number, center-aligned with the text.
  static final _amountBeforeMarker =
      RegExp(r'([+-]?[\d,]*\.?\d+[KMB]?)\s*◆');

  @override
  Widget build(BuildContext context) {
    final size = iconSize ?? style?.fontSize ?? 13;
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in _amountBeforeMarker.allMatches(text)) {
      if (match.start > cursor) {
        children.add(
          TextSpan(text: text.substring(cursor, match.start), style: style),
        );
      }
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: CoinIcon(size: size, color: iconColor),
        ),
      );
      children.add(TextSpan(text: match.group(1), style: style));
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: style));
    }
    // No markers: plain text path.
    if (children.isEmpty) {
      return Text(text, style: style, textAlign: textAlign);
    }
    return Text.rich(
      TextSpan(children: children),
      textAlign: textAlign,
    );
  }
}
