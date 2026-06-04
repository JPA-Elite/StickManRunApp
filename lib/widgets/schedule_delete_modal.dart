import 'package:flutter/material.dart';

class ScheduleDeleteModal extends StatefulWidget {
  final bool isOpen;
  final String? currentScheduleIso;
  final void Function(DateTime? when) onSchedule; // null => remove schedule
  final VoidCallback onClose;

  const ScheduleDeleteModal({
    super.key,
    required this.isOpen,
    required this.currentScheduleIso,
    required this.onSchedule,
    required this.onClose,
  });

  @override
  State<ScheduleDeleteModal> createState() => _ScheduleDeleteModalState();
}

class _ScheduleDeleteModalState extends State<ScheduleDeleteModal> {
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  bool get _hasSchedule => widget.currentScheduleIso != null && widget.currentScheduleIso!.isNotEmpty;

  String get _currentScheduleLabel {
    final when = DateTime.tryParse(widget.currentScheduleIso ?? '');
    if (when == null) return '';
    final local = when.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(widget.currentScheduleIso ?? '') ?? now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now.add(const Duration(days: 1)) : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;

    _dateController.text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked == null) return;

    _timeController.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  void _handleSchedule() {
    if (!_hasSchedule || _dateController.text.isEmpty || _timeController.text.isEmpty) {
      // allow both "set" and "remove"
      if (_dateController.text.isEmpty || _timeController.text.isEmpty) return;
    }

    final date = _dateController.text.trim();
    final time = _timeController.text.trim();

    final dt = DateTime.tryParse('${date}T${time}');
    if (dt == null) return;

    if (dt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future date/time')),
      );
      return;
    }

    widget.onSchedule(dt);
    widget.onClose();
    _dateController.clear();
    _timeController.clear();
  }

  void _handleRemove() {
    widget.onSchedule(null);
    widget.onClose();
    _dateController.clear();
    _timeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Schedule Delete',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set when this note should be automatically deleted.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_hasSchedule)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('Currently scheduled for', style: TextStyle(fontSize: 12, color: Colors.orange)),
                            const SizedBox(height: 4),
                            Text(_currentScheduleLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(_dateController.text.isEmpty ? 'Pick Date' : _dateController.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time),
                            label: Text(_timeController.text.isEmpty ? 'Pick Time' : _timeController.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_hasSchedule)
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _handleRemove,
                              child: const Text('Remove'),
                            ),
                          )
                        else
                          const SizedBox(width: 8),
                        if (_hasSchedule) const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onClose,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: (_dateController.text.isNotEmpty && _timeController.text.isNotEmpty)
                                ? _handleSchedule
                                : null,
                            child: const Text('Schedule'),
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
}
