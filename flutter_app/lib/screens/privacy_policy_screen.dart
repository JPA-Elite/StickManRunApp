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
          title: 'Your Privacy Matters',
          body:
              'We are committed to protecting your privacy. This policy explains how we handle your data.',
        ),
        _Section(
          title: 'Data Storage',
          body:
              'All your notes are stored locally on your device. We do not have access to your notes.',
        ),
        _Section(
          title: 'Data Security',
          body:
              'Your data security is important to us: no data transmitted to external servers.',
        ),
        _Section(
          title: 'Information We Collect',
          body:
              'We collect minimal information: note content and app preferences/setting values.',
        ),
        _Section(
          title: 'Your Rights',
          body:
              'You have full control over your data: export all notes and delete all data permanently.',
        ),
        SizedBox(height: 8),
        Text(
          'Last updated: May 22, 2026',
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
          Text(body),
        ],
      ),
    );
  }
}
