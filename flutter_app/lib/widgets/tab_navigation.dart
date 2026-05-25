import 'package:flutter/material.dart';

enum TabRoute { notes, create, reminders, settings }

class TabNavigation extends StatelessWidget {
  final TabRoute active;
  final VoidCallback onNotes;
  final VoidCallback onCreate;
  final VoidCallback onReminders;
  final VoidCallback onSettings;

  const TabNavigation({
    super.key,
    required this.active,
    required this.onNotes,
    required this.onCreate,
    required this.onReminders,
    required this.onSettings,
  });

  int get _index {
    switch (active) {
      case TabRoute.notes:
        return 0;
      case TabRoute.create:
        return 1;
      case TabRoute.reminders:
        return 2;
      case TabRoute.settings:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _index,
      onTap: (i) {
        if (i == 0) onNotes();
        if (i == 1) onCreate();
        if (i == 2) onReminders();
        if (i == 3) onSettings();
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.note),
          label: 'Notes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.edit_note),
          label: 'Create',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.alarm),
          label: 'Reminders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      backgroundColor:
          Theme.of(context).bottomAppBarTheme.color ?? Theme.of(context).colorScheme.surface,
      type: BottomNavigationBarType.fixed,
    );
  }
}
