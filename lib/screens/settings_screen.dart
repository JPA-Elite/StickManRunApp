import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/notes_repository.dart';
import '../state/theme_controller.dart';
import '../widgets/tab_navigation.dart';
import '../widgets/top_toast.dart';

class SettingsScreen extends StatefulWidget {
  final NotesRepository notesRepository;
  final ThemeController themeController;

  const SettingsScreen({
    super.key,
    required this.notesRepository,
    required this.themeController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _themeBusy = false;

  Future<void> _exportNotes() async {
    setState(() => _busy = true);
    try {
      final json = await widget.notesRepository.exportNotesJson();

      final dir = await Directory.systemTemp.createTemp('notebookmobileapp_');
      final path =
          '${dir.path}/notes-backup-${DateTime.now().toIso8601String().split("T").first}.json';

      final file = File(path);
      await file.writeAsString(json, flush: true);

      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/json')],
        text: 'Notes backup',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete All Notes?'),
        content: const Text(
          'Are you sure you want to delete all notes? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.notesRepository.clearAll();
      if (!mounted) return;

      TopToast.show(context, message: 'All notes deleted');

      if (Navigator.canPop(context)) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.themeController.darkMode;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile(
                title: const Text('Dark Mode'),
                value: darkMode,
                secondary: _themeBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onChanged: _themeBusy
                    ? null
                    : (value) async {
                        setState(() => _themeBusy = true);
                        try {
                          await widget.themeController.toggleDarkMode();
                        } finally {
                          if (mounted) setState(() => _themeBusy = false);
                        }
                      },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export Notes'),
                subtitle: const Text('Share a JSON backup'),
                trailing: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _busy ? null : _exportNotes,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Clear All Notes',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text('Delete everything from local storage'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _clearAll,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Use'),
                subtitle: const Text('User responsibilities and limitations'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/terms'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('FAQs'),
                subtitle: const Text('Frequently asked questions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/faqs'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text('How your data is handled'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/privacy'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: TabNavigation(
          active: TabRoute.settings,
          onNotes: () => Navigator.of(context).pushNamed('/notes'),
          onReminders: () => Navigator.of(context).pushNamed('/reminders'),
          onSettings: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ),
    );
  }
}
