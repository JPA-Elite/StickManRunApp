import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/reminders_repository.dart';
import '../models/reminder.dart';
import '../services/local_notifications_service.dart';
import '../widgets/tab_navigation.dart';
import '../widgets/top_toast.dart';

class RemindersScreen extends StatefulWidget {
  final RemindersRepository remindersRepository;

  const RemindersScreen({
    super.key,
    required this.remindersRepository,
  });

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _busy = false;
  List<Reminder> _reminders = const [];

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  DateTime? _pickedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final reminders = await widget.remindersRepository.getReminders();
      // Show nearest first.
      reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      setState(() => _reminders = reminders);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _pickedAt ?? now.add(const Duration(minutes: 5));

    final date = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(initialDate),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() => _pickedAt = dt);
  }

  Future<void> _createReminder() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final pickedAt = _pickedAt;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (pickedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date/time')),
      );
      return;
    }

    if (pickedAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a future time')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final reminderId = now.millisecondsSinceEpoch.toString();

      final reminder = Reminder(
        id: reminderId,
        title: title,
        message: message,
        scheduledAt: pickedAt,
        createdAt: now,
      );

      await widget.remindersRepository.addReminder(reminder);

      // Schedule notification.
      final service = LocalNotificationsService();
      await service.init();
      final location = tz.local;
      final scheduled = tz.TZDateTime.from(pickedAt, location);

      await service.scheduleOneShot(
        id: int.parse(reminderId),
        title: title,
        body: message.isEmpty ? 'Reminder' : message,
        scheduledDate: scheduled,
        payload: reminderId,
      );

      _titleController.clear();
      _messageController.clear();
      setState(() => _pickedAt = null);

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder scheduled')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to schedule reminder: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    setState(() => _busy = true);
    try {
      await widget.remindersRepository.deleteReminder(reminder.id);

      final service = LocalNotificationsService();
      await service.init();
      final idInt = int.tryParse(reminder.id);
      if (idInt != null) {
        await service.cancel(idInt);
      }

      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Reminders'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Take medicine',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message (optional)',
                        hintText: 'e.g. After breakfast',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_outlined),
                      title: Text(
                        _pickedAt == null
                            ? 'Pick date & time'
                            : _pickedAt!.toLocal().toString().split('.').first,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : _pickDateTime,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _createReminder,
                        icon: const Icon(Icons.alarm_add_outlined),
                        label: const Text('Schedule'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scheduled reminders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_busy && _reminders.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else if (_reminders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No reminders scheduled yet.'),
              )
            else
              for (final r in _reminders)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.alarm),
                    title: Text(r.title),
                    subtitle: Text(
                      r.scheduledAt.toLocal().toString().split('.').first,
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete reminder',
                      onPressed: _busy ? null : () => _deleteReminder(r),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ),
                ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: TabNavigation(
          active: TabRoute.reminders,
          onNotes: () => Navigator.of(context).pushNamed('/notes'),
          onReminders: () {},
          onSettings: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ),
    );
  }
}
