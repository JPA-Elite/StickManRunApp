import 'dart:async';

import 'package:flutter/material.dart';

enum PinLockMode { set, verify }

class PinLockModal extends StatefulWidget {
  final PinLockMode mode;
  final bool isOpen; // allow inline usage in bottomSheet
  final String? correctPin;

  final void Function(String pin)? onSetSuccess;
  final VoidCallback? onVerified;
  final VoidCallback? onClosed;

  const PinLockModal({
    super.key,
    required this.mode,
    required this.isOpen,
    this.correctPin,
    this.onSetSuccess,
    this.onVerified,
    this.onClosed,
  });

  @override
  State<PinLockModal> createState() => _PinLockModalState();
}

class _PinLockModalState extends State<PinLockModal> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  int _attempts = 0;
  DateTime? _cooldownUntil;

  bool get _isLocked =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  int get _remainingCooldownSeconds => _cooldownUntil == null
      ? 0
      : (_cooldownUntil!.difference(DateTime.now()).inSeconds).clamp(0, 1 << 31);

  Timer? _tickTimer;

  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (_cooldownUntil != null) {
      _startCooldownTimer();
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_cooldownUntil == null) return;
      if (DateTime.now().isAfter(_cooldownUntil!)) {
        setState(() {
          _cooldownUntil = null;
          _attempts = 0;
          _errorText = null;
        });
        _tickTimer?.cancel();
      } else {
        setState(() {}); // refresh remaining seconds UI
      }
    });
  }

  void _close() {
    _tickTimer?.cancel();
    _pinController.clear();
    _confirmController.clear();
    _attempts = 0;
    _cooldownUntil = null;
    _errorText = null;
    widget.onClosed?.call();
  }

  void _handleSubmit() {
    if (!_isOpen) return;
    setState(() {
      _errorText = null;
    });

    if (_isLocked) {
      setState(() {
        _errorText = 'Too many attempts. Please wait $_remainingCooldownSeconds s';
      });
      return;
    }

    final pin = _pinController.text.trim();
    if (pin.length < 6) {
      setState(() {
        _errorText = 'PIN must be at least 6 digits';
      });
      return;
    }

    if (widget.mode == PinLockMode.verify) {
      final correct = widget.correctPin ?? '';
      if (pin == correct) {
        _close();
        widget.onVerified?.call();
      } else {
        final newAttempts = _attempts + 1;
        if (newAttempts >= 5) {
          final until = DateTime.now().add(const Duration(seconds: 30));
          setState(() {
            _attempts = newAttempts;
            _cooldownUntil = until;
            _errorText = 'Too many attempts. Locked for 30 seconds';
          });
          _startCooldownTimer();
        } else {
          setState(() {
            _attempts = newAttempts;
            _errorText = 'Incorrect PIN. ${5 - newAttempts} attempts remaining';
            _pinController.clear();
          });
        }
      }
      return;
    }

    // set mode
    final confirm = _confirmController.text.trim();
    if (widget.correctPin != null) {
      // not used; left for forward compatibility
    }
    if (confirm.isEmpty) {
      // In "set" mode we require two-step, so confirm is required
      setState(() {
        _errorText = 'Confirm your PIN';
      });
      return;
    }

    if (pin != confirm) {
      setState(() {
        _errorText = 'PINs do not match';
        _confirmController.clear();
      });
      return;
    }

    _close();
    widget.onSetSuccess?.call(pin);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final title = widget.mode == PinLockMode.set ? 'Set PIN Lock' : 'Enter PIN';
    final subtitle = widget.mode == PinLockMode.set
        ? 'Create a 6-digit PIN to lock this note'
        : 'Enter your PIN to unlock this note';

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _pinController,
                      enabled: !_isLocked,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Enter PIN',
                        errorText: _errorText,
                      ),
                      onChanged: (v) {
                        final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digitsOnly != v) {
                          _pinController.value =
                              TextEditingValue(text: digitsOnly);
                        }
                      },
                      onSubmitted: (_) => _handleSubmit(),
                    ),

                    if (widget.mode == PinLockMode.set) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmController,
                        enabled: !_isLocked,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'Confirm PIN',
                          errorText: null,
                        ),
                        onChanged: (v) {
                          final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
                          if (digitsOnly != v) {
                            _confirmController.value =
                                TextEditingValue(text: digitsOnly);
                          }
                        },
                        onSubmitted: (_) => _handleSubmit(),
                      ),
                    ],

                    if (widget.mode == PinLockMode.verify && _attempts > 0 && !_isLocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${5 - _attempts} attempts remaining',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),

                    if (_isLocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            Text(
                              'Too many failed attempts',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$_remainingCooldownSeconds s',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _close,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                _isLocked ? null : _handleSubmit,
                            child: Text(widget.mode == PinLockMode.set
                                ? 'Set Lock'
                                : 'Unlock'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _isOpen => widget.isOpen;
}
