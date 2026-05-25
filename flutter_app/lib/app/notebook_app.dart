import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timezone/timezone.dart' as tz;

import '../data/notes_repository.dart';
import '../data/reminders_repository.dart';
import '../state/theme_controller.dart';
import '../services/local_notifications_service.dart';
import '../screens/notes_list_screen.dart';
import '../screens/create_note_screen.dart';
import '../screens/note_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/terms_of_use_screen.dart';
import '../screens/reminders_screen.dart';

class NotebookApp extends StatefulWidget {
  const NotebookApp({super.key});

  @override
  State<NotebookApp> createState() => _NotebookAppState();
}

class _NotebookAppState extends State<NotebookApp> {
  bool _bootstrapped = false;
  late final NotesRepository _notesRepository;
  late final RemindersRepository _remindersRepository;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _notesRepository = NotesRepository(prefs: prefs);
    _remindersRepository = RemindersRepository(prefs: prefs);
    _themeController = ThemeController(prefs: prefs);

    // Purge expired scheduled deletes on startup.
    await _notesRepository.purgeExpiredScheduledDeletes();

    // Initialize reminders notifications + reschedule from local storage.
    final notifications = LocalNotificationsService();
    await notifications.init();
    await notifications.requestPermissions();

    await _remindersRepository.purgeExpiredReminders();

    final now = DateTime.now();
    final reminders = await _remindersRepository.getReminders();
    for (final r in reminders) {
      if (r.scheduledAt.isBefore(now)) continue;

      final reminderId = int.tryParse(r.id);
      if (reminderId == null) continue;

      final scheduled = tz.TZDateTime.from(r.scheduledAt, tz.local);

      await notifications.scheduleOneShot(
        id: reminderId,
        title: r.title,
        body: r.message.isEmpty ? 'Reminder' : r.message,
        scheduledDate: scheduled,
        payload: r.id,
      );
    }

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
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          initialRoute: '/notes',
          onGenerateRoute: (settings) {
            // Keep tab switches (notes/create/settings/privacy) instant so
            // the fade animation doesn't affect the bottom navigation.
            if (settings.name == '/notes') {
              return PageRouteBuilder(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (routeContext, _, __) => NotesListScreen(
                  notesRepository: _notesRepository,
                  themeController: _themeController,
                ),
              );
            }

            if (settings.name == '/create') {
              return PageRouteBuilder(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (routeContext, _, __) => CreateNoteScreen(
                  notesRepository: _notesRepository,
                  onBackToNotes: () => Navigator.of(routeContext).pop(),
                ),
              );
            }

            if (settings.name == '/settings') {
              return PageRouteBuilder(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (context, _, __) => SettingsScreen(
                  notesRepository: _notesRepository,
                  themeController: _themeController,
                ),
              );
            }

            if (settings.name == '/privacy') {
              return PageRouteBuilder(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (context, _, __) => const PrivacyPolicyScreen(),
              );
            }

            if (settings.name == '/terms') {
              return PageRouteBuilder(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (context, _, __) => const TermsOfUseScreen(),
              );
            }

            if (settings.name == '/reminders') {
              return PageRouteBuilder(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (context, _, __) => RemindersScreen(
                  remindersRepository: _remindersRepository,
                ),
              );
            }

            if (settings.name == '/note') {
              final id = settings.arguments as String;
              return MaterialPageRoute(
                builder: (routeContext) => NoteDetailScreen(
                  notesRepository: _notesRepository,
                  noteId: id,
                  onBack: () => Navigator.of(routeContext).pop(),
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
