import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/notes_repository.dart';
import '../models/note.dart';
import '../utils/quill_delta_utils.dart';
import '../widgets/tab_navigation.dart';

class CreateNoteScreen extends StatefulWidget {
  final NotesRepository notesRepository;
  final VoidCallback onBackToNotes;

  const CreateNoteScreen({
    super.key,
    required this.notesRepository,
    required this.onBackToNotes,
  });

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _titleController = TextEditingController();

  bool _toolbarExpanded = true;

  final List<NoteAttachmentDraft> _attachments = [];

  bool _saving = false;

  // Quill
  late QuillController _quillController;

  // Voice -> structured notes (offline heuristic)
  final SpeechToText _speechToText = SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speechToText.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (res == null) return;

    for (final f in res.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;

      // 10MB max (matches web logic).
      if (bytes.lengthInBytes > 10 * 1024 * 1024) continue;

      final type = (f.extension != null && f.extension!.isNotEmpty)
          ? 'file/${f.extension}'
          : 'application/octet-stream';

      _attachments.add(
        NoteAttachmentDraft(
          name: f.name,
          type: type,
          base64Data: base64Encode(bytes),
        ),
      );
    }

    setState(() {});
  }

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    setState(() {
      _transcript = '';
      _listening = true;
    });

    await _speechToText.listen(
      onResult: (res) {
        setState(() {
          _transcript = res.recognizedWords;
        });
      },
    );
  }

  Future<void> _stopListeningAndApply() async {
    await _speechToText.stop();
    if (!mounted) return;

    setState(() => _listening = false);

    final transcript = _transcript.trim();
    if (transcript.isEmpty) return;

    final structured = _structureTranscript(transcript);

    final maybeTitle = structured.title.trim();
    if (_titleController.text.trim().isEmpty && maybeTitle.isNotEmpty) {
      _titleController.text = maybeTitle;
    }

    // Update quill document from structured body (plain text -> delta json -> Document.fromJson).
    final deltaJsonString = plainTextToDeltaJsonString(structured.body);
    final document = Document.fromJson(jsonDecode(deltaJsonString));

    _quillController.document = document;

    setState(() {});
  }

  _StructuredNote _structureTranscript(String transcript) {
    // Offline-only heuristic:
    // - First sentence -> title
    // - Remaining sentences -> bullet list
    final cleaned = transcript
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\.+\s*$'), '.')
        .trim();

    final parts = cleaned.split(RegExp(r'(?<=[.!?])\s+'));
    final title = parts.isNotEmpty ? parts.first : cleaned;

    final rest = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final bullets = rest
        .split(RegExp(r'[,;]\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final bodyBuffer = StringBuffer();
    if (title.isNotEmpty) bodyBuffer.writeln(title);

    if (bullets.isEmpty) {
      bodyBuffer.writeln();
      bodyBuffer.writeln(rest.isEmpty ? cleaned : rest);
    } else {
      bodyBuffer.writeln();
      for (final b in bullets) {
        bodyBuffer.writeln('- $b');
      }
    }

    return _StructuredNote(
      title: title,
      body: bodyBuffer.toString().trim(),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _titleController.text.trim();
    final contentDeltaJson = quillDocumentToDeltaJsonString(_quillController.document);

    final isContentEmpty = quillDeltaContentToPlainText(contentDeltaJson).trim().isEmpty;
    if (title.isEmpty && isContentEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title or content')),
      );
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now();
    final note = Note(
      id: now.millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Untitled Note' : title,
      contentDeltaJson: contentDeltaJson,
      createdAt: now,
      updatedAt: now,
      attachments: _attachments
          .map(
            (d) => NoteAttachment(
              name: d.name,
              type: d.type,
              base64Data: d.base64Data,
            ),
          )
          .toList(growable: false),
      isLocked: false,
    );

    await widget.notesRepository.addNote(note);

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onBackToNotes();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Note'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToNotes,
        ),
        actions: [
          if (_speechAvailable)
            IconButton(
              icon: Icon(_listening ? Icons.mic : Icons.mic_none),
              tooltip: _listening ? 'Stop voice input' : 'Voice to structured notes',
              onPressed: () async {
                if (_listening) {
                  await _stopListeningAndApply();
                } else {
                  await _startListening();
                }
              },
            ),
          IconButton(
            icon: Icon(_toolbarExpanded ? Icons.unfold_less : Icons.unfold_more),
            tooltip: _toolbarExpanded ? 'Minimize editor toolbar' : 'Expand editor toolbar',
            onPressed: () {
              setState(() => _toolbarExpanded = !_toolbarExpanded);
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Note title',
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            if (_attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in _attachments)
                      Chip(
                        label: Text(
                          a.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: () {
                          _attachments.remove(a);
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            Row(
              children: [
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _pickAttachments,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach File'),
                ),
                const SizedBox(width: 16),
              ],
            ),

            if (_speechAvailable && _listening)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Listening... ${_transcript.isEmpty ? '' : "(${_transcript.length} chars)"}',
                  style: theme.textTheme.bodySmall,
                ),
              ),

            const SizedBox(height: 12),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SizedBox(
                      height: _toolbarExpanded ? 120 : 44,
                      child: ClipRect(
                        child: QuillSimpleToolbar(
                          controller: _quillController,
                          config: QuillSimpleToolbarConfig(
                            multiRowsDisplay: _toolbarExpanded,
                            toolbarSize: _toolbarExpanded ? 48 : 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: QuillEditor.basic(
                        controller: _quillController,
                        config: const QuillEditorConfig(
                          placeholder: 'Start writing your note...',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: TabNavigation(
          active: TabRoute.create,
          onNotes: () => Navigator.of(context).pushNamed('/notes'),
          onCreate: () => Navigator.of(context).pushNamed('/create'),
          onSettings: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ),
    );
  }
}

class NoteAttachmentDraft {
  final String name;
  final String type;
  final String base64Data;

  const NoteAttachmentDraft({
    required this.name,
    required this.type,
    required this.base64Data,
  });
}

class _StructuredNote {
  final String title;
  final String body;

  const _StructuredNote({
    required this.title,
    required this.body,
  });
}
