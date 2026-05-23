import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/notes_repository.dart';
import '../state/theme_controller.dart';
import '../screens/notes_list_screen.dart';
import '../screens/create_note_screen.dart';
import '../screens/note_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/privacy_policy_screen.dart';

class NotebookApp extends StatefulWidget {
  const NotebookApp({super.key});

  @override
  State<NotebookApp> createState() => _NotebookAppState();
}

class _NotebookAppState extends State<NotebookApp> {
  bool _bootstrapped = false;
  late final NotesRepository _notesRepository;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _notesRepository = NotesRepository(prefs: prefs);
    _themeController = ThemeController(prefs: prefs);

    // Purge expired scheduled deletes on startup.
    await _notesRepository.purgeExpiredScheduledDeletes();

    if (!mounted) return;
    setState(() {
      _bootstrapped = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final themeMode = _themeController.themeMode;

    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: _themeController.themeMode,
          theme: _themeController.lightTheme,
          darkTheme: _themeController.darkTheme,
          initialRoute: '/notes',
          routes: {
            '/notes': (context) => NotesListScreen(
                  notesRepository: _notesRepository,
                  onCreate: () => Navigator.of(context).pushNamed('/create'),
                  onOpenNote: (id) =>
                      Navigator.of(context).pushNamed('/note', arguments: id),
                  themeController: _themeController,
                ),
            '/create': (context) => CreateNoteScreen(
                  notesRepository: _notesRepository,
                  onBackToNotes: () => Navigator.of(context).pop(),
                ),
            '/settings': (context) => SettingsScreen(
                  notesRepository: _notesRepository,
                  themeController: _themeController,
                ),
            '/privacy': (context) => const PrivacyPolicyScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/note') {
              final id = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => NoteDetailScreen(
                  notesRepository: _notesRepository,
                  noteId: id,
                  onBack: () => Navigator.of(context).pop(),
                ),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
