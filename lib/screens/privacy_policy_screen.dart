import 'package:flutter/material.dart';

import '../data/notes_repository.dart';
import '../state/theme_controller.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: _PrivacyPolicyBody(),
      ),
    );
  }
}

class _PrivacyPolicyBody extends StatelessWidget {
  const _PrivacyPolicyBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Section(
          title: 'Summary',
          body:
              'Notebook Mobile App stores your notes locally on your device. This means your notes are not intentionally uploaded to our servers (there are no dedicated backend servers for note content in this app).',
        ),
        _Section(
          title: 'Data We Store',
          body:
              'Notes: Your note title, content, attachments (optional), and note metadata (e.g., lock state and scheduled delete time) are stored locally.\n\n'
              'Settings: Your theme preference (light/dark mode) is stored locally.\n\n'
              'Lock PIN: If you lock a note using the in-app PIN flow, the PIN value is stored locally for that note so the app can unlock it later.',
        ),
        _Section(
          title: 'Where This Data Is Stored (Local Only)',
          body:
              'Non-web: Notes are persisted to a local JSON file in your app documents directory (for example, a file named notes.json).\n\n'
              'Web: Notes are stored using SharedPreferences in your browser/app storage.\n\n'
              'Backups/Export: When you choose “Export Notes”, the app generates a JSON backup on your device and shares it using your device’s share sheet.',
        ),
        _Section(
          title: 'What Happens With Attachments',
          body:
              'If you attach a file, the app stores the attachment name/type and the file contents (base64-encoded) locally as part of the note record.\n\n'
              'Opening attachments later uses the stored data to recreate a temporary file and then opens it using the platform file opener.',
        ),
        _Section(
          title: 'Biometrics and PIN Unlock',
          body:
              'The app uses the device’s biometric APIs (through the local_auth plugin) to authenticate unlock attempts. Biometric processing is handled by your operating system.\n\n'
              'PIN unlock uses the PIN value stored for the note (local storage). The PIN is not sent to external services by the app.',
        ),
        _Section(
          title: 'Voice-to-Text',
          body:
              'If you use the in-app voice-to-structured-notes feature, the app uses the speech_to_text plugin to obtain recognized speech.\n\n'
              'Recognition may be performed on-device or may rely on external services depending on your platform and device capabilities. This app only uses the recognized transcript text for note creation and does not intentionally store raw audio.\n\n'
              'You can review and change what ends up in the note after speech recognition (the transcript is used to prefill the editor).',
        ),
        _Section(
          title: 'Sharing and Export',
          body:
              'Export Notes creates a JSON file from your locally stored notes and shares it via the OS “share” mechanism.\n\n'
              'When you share this file, your chosen recipients/services may handle the data according to their own policies.',
        ),
        _Section(
          title: 'Deletion',
          body:
              'You can delete individual notes or clear all notes. Deleted notes are removed from local storage.\n\n'
              'The app also supports scheduled deletes. When a scheduled deletion time passes, the app purges those notes during app startup and periodically while the app is open.',
        ),
        _Section(
          title: 'Security Notes',
          body:
              'This app is designed as a local-only notes app. However, lock PIN values and note data are stored locally by the app.\n\n'
              'If you lock notes with a PIN, consider using strong device security (screen lock, biometrics, etc.).',
        ),
        _Section(
          title: 'Your Choices',
          body:
              'You control your notes on your device. You can export a backup or delete all local data at any time from Settings.',
        ),
        _Section(
          title: 'Contact',
          body:
              'If you have questions or need help exporting or deleting your local data, use the app’s export/clear actions in Settings.',
        ),
        SizedBox(height: 8),
        Text(
          'Last updated: May 25, 2026',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        )
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
