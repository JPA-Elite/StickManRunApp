import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Use'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: _TermsBody(),
      ),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Section(
          title: '1) Acceptance of Terms',
          body:
              'By using Notebook Mobile App (“the App”), you agree to these Terms of Use (“Terms”). If you do not agree, you must not use the App.',
        ),
        _Section(
          title: '2) Local-Only Notes (No App Server)',
          body:
              'This App is designed to store your notes locally on your device. The App does not intentionally upload your note content to external servers.\n\n'
              'If you choose to export or share a backup, that action will generate a JSON file on your device and use your device’s share mechanism. Any recipients may process the exported data according to their own policies.',
        ),
        _Section(
          title: '3) Your Content & Acceptable Use',
          body:
              'You are solely responsible for the notes you create, edit, lock, and export.\n\n'
              'You agree not to use the App to store or share content that violates applicable laws or rights of others.',
        ),
        _Section(
          title: '4) Locking Notes with PIN and Biometrics',
          body:
              'The App supports locking notes with a PIN and optionally unlocking with device biometrics (where available).\n\n'
              'You acknowledge that:\n'
              '• The lock is enforced by the App using your device’s local storage.\n'
              '• If someone gains access to your device while you are logged in/unlocked, they may be able to view your notes.\n'
              '• You should use your device’s security features (screen lock, biometric lock, etc.) to protect your data.\n\n'
              'For PINs, the PIN value is stored locally so the App can unlock the note. The App does not intentionally send PIN values to external services.',
        ),
        _Section(
          title: '5) Voice-to-Text (Offline Template Heuristics)',
          body:
              'The App includes a voice-to-structured-notes feature that uses the device speech recognition integration.\n\n'
              'You understand that:\n'
              '• Speech recognition results can be inaccurate.\n'
              '• The App uses an offline heuristic to convert recognized text into a structured note (for example: first sentence as a title, remaining content as bullet points).\n'
              '• You are responsible for reviewing and correcting the final note content before saving.',
        ),
        _Section(
          title: '6) Export, Sharing, and Backups',
          body:
              'When you export notes, the App generates a JSON backup on your device and shares it via the operating system’s share sheet.\n\n'
              'You are responsible for how you share, store, and protect exported files. The App cannot control how other apps or recipients handle exported data.',
        ),
        _Section(
          title: '7) Deletion & Scheduled Deletion',
          body:
              'You may delete notes individually or clear all local notes. The App also supports scheduled deletion.\n\n'
              'Scheduled deletion purges notes that are due when the app runs (on startup and periodically while open). If you do not keep the app running, scheduled deletions may occur later than the scheduled time.',
        ),
        _Section(
          title: '8) User Controls',
          body:
              'You control your data through the App’s Settings actions such as export and clear-all.\n\n'
              'If you choose to remove local data, it cannot be restored unless you have your own backup.',
        ),
        _Section(
          title: '9) Disclaimer of Warranties',
          body:
              'The App is provided “as is” and “as available”. To the maximum extent permitted by law, we disclaim all warranties, including implied warranties of merchantability, fitness for a particular purpose, and non-infringement.',
        ),
        _Section(
          title: '10) Limitation of Liability',
          body:
              'To the maximum extent permitted by law, we will not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of data, arising out of or related to your use of the App.\n\n'
              'You acknowledge that local storage can be affected by device issues, OS changes, app uninstall/reinstall, or storage corruption. Keeping backups is recommended.',
        ),
        _Section(
          title: '11) Changes to These Terms',
          body:
              'We may update these Terms from time to time. Continued use of the App means you accept the latest version.',
        ),
        SizedBox(height: 8),
        Text(
          'Last updated: May 25, 2026',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
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
          Text(body),
        ],
      ),
    );
  }
}
