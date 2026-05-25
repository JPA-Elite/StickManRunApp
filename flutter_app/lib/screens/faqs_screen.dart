import 'package:flutter/material.dart';

class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = <_Faq>[
      _Faq(
        question: 'How do I create a note?',
        answer:
            'Open “Notes”, tap the + button, then fill in your title and content. Your note will be saved automatically.',
      ),
      _Faq(
        question: 'Can I lock a note?',
        answer:
            'Yes. In your notes list, locked notes can be unlocked using your PIN lock flow. Locked notes protect your content from casual viewing.',
      ),
      _Faq(
        question: 'How do reminders work?',
        answer:
            'Go to “Reminders”, set a title/message, pick a date & time, then press “Schedule”. The app will create a local notification for that time.',
      ),
      _Faq(
        question: 'Where are my notes stored?',
        answer:
            'Notes are stored locally on your device. “Export Notes” lets you create a JSON backup file you can share.',
      ),
      _Faq(
        question: 'What happens when I clear all notes?',
        answer:
            '“Clear All Notes” deletes all notes from local storage. This action can’t be undone.',
      ),
      _Faq(
        question: 'Do I need an internet connection?',
        answer:
            'No. Notes and reminders are stored locally and scheduled using local notifications, so the app works offline.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('FAQs'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Frequently Asked Questions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ...faqs.map((faq) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FaqAccordion(
                  question: faq.question,
                  answer: faq.answer,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Faq {
  final String question;
  final String answer;

  const _Faq({
    required this.question,
    required this.answer,
  });
}

class _FaqAccordion extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqAccordion({
    required this.question,
    required this.answer,
  });

  @override
  State<_FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<_FaqAccordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    _open ? Icons.remove_circle_outline : Icons.add_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            crossFadeState:
                _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.answer,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
