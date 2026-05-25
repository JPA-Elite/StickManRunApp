import 'package:flutter/material.dart';

class TopToast {
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    final brightness = Theme.of(context).brightness;

    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF1F2937) // dark slate-ish
        : Colors.white;

    final fgColor = brightness == Brightness.dark ? Colors.white : Colors.black;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Positioned(
          top: media.padding.top + 12,
          left: 0,
          right: 0,
          child: SafeArea(
            child: IgnorePointer(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Material(
                    color: bgColor,
                    elevation: 8,
                    shadowColor: brightness == Brightness.dark
                        ? Colors.black54
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: fgColor,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fgColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(duration).then((_) {
      if (entry.mounted) entry.remove();
    });
  }
}
