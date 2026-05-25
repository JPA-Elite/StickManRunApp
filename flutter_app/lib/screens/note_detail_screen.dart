import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../data/notes_repository.dart';
import '../models/note.dart';
import '../widgets/pin_lock_modal.dart';
import '../widgets/schedule_delete_modal.dart';

class NoteDetailScreen extends StatefulWidget {
  final NotesRepository notesRepository;
  final String noteId;
  final VoidCallback onBack;

  const NoteDetailScreen({
    super.key,
    required this.notesRepository,
    required this.noteId,
    required this.onBack,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  Note? _note;

  bool _loading = true;
  bool _isEditing = false;

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  List<NoteAttachment> _draftAttachments = [];

  bool _pinModalOpen = false;
  bool _scheduleModalOpen = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final notes = await widget.notesRepository.getNotes();
    final found = notes
        .where((n) => n.id == widget.noteId)
        .cast<Note?>()
        .firstOrNull;

    if (found == null) {
      if (!mounted) return;
      setState(() => _note = null);
      widget.onBack();
      return;
    }

    setState(() {
      _note = found;
      _titleController.text = found.title;
      _contentController.text = found.contentDeltaJson;
      _draftAttachments = List<NoteAttachment>.from(found.attachments);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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

      // Keep consistent with CreateNote limit.
      if (bytes.lengthInBytes > 10 * 1024 * 1024) continue;

      final type = (f.extension != null && f.extension!.isNotEmpty)
          ? 'file/${f.extension}'
          : 'application/octet-stream';

      _draftAttachments.add(
        NoteAttachment(
          name: f.name,
          type: type,
          base64Data: base64Encode(bytes),
        ),
      );
    }

    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title or content')),
      );
      return;
    }

    final existing = _note;
    if (existing == null) return;

    final updated = Note(
      id: existing.id,
      title: title.isEmpty ? 'Untitled Note' : title,
      contentDeltaJson: content,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      attachments: List<NoteAttachment>.from(_draftAttachments),
      isLocked: existing.isLocked,
      pin: existing.pin,
      scheduledDeleteIso: existing.scheduledDeleteIso,
    );

    await widget.notesRepository.updateNote(updated);
    await _load();

    if (!mounted) return;
    setState(() => _isEditing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note updated successfully!')),
    );
  }

  Future<void> _deleteNote() async {
    final existing = _note;
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.notesRepository.deleteNote(existing.id);
    widget.onBack();
  }

  Future<void> _applyLockFromPin(String pin) async {
    final existing = _note;
    if (existing == null) return;

    final updated = Note(
      id: existing.id,
      title: existing.title,
      contentDeltaJson: _contentController.text,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      attachments: List<NoteAttachment>.from(_draftAttachments),
      isLocked: true,
      pin: pin,
      scheduledDeleteIso: existing.scheduledDeleteIso,
    );

    await widget.notesRepository.updateNote(updated);
    await _load();

    if (!mounted) return;
    setState(() => _pinModalOpen = false);
  }

  Future<void> _unlockWithPinSuccess() async {
    final existing = _note;
    if (existing == null) return;

    final updated = Note(
      id: existing.id,
      title: existing.title,
      contentDeltaJson: _contentController.text,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      attachments: List<NoteAttachment>.from(_draftAttachments),
      isLocked: false,
      pin: null,
      scheduledDeleteIso: existing.scheduledDeleteIso,
    );

    await widget.notesRepository.updateNote(updated);
    await _load();

    if (!mounted) return;
    setState(() => _pinModalOpen = false);
  }

  Future<void> _setSchedule(DateTime? when) async {
    final existing = _note;
    if (existing == null) return;

    final updated = Note(
      id: existing.id,
      title: existing.title,
      contentDeltaJson: _contentController.text,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      attachments: List<NoteAttachment>.from(_draftAttachments),
      isLocked: existing.isLocked,
      pin: existing.pin,
      scheduledDeleteIso: when?.toIso8601String(),
    );

    await widget.notesRepository.updateNote(updated);
    await _load();

    if (!mounted) return;
    setState(() => _scheduleModalOpen = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(when == null ? 'Schedule removed' : 'Delete scheduled'),
      ),
    );
  }

  Future<void> _openAttachment(NoteAttachment a) async {
    final bytes = base64Decode(a.base64Data);

    final dir = await getTemporaryDirectory();
    final safeName = a.name.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    final filePath = '${dir.path}/$safeName';

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await OpenFilex.open(filePath);
  }

  Widget _buildAttachmentsSection(Note note) {
    if (note.attachments.isEmpty && !_isEditing) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Attachments',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_isEditing) ...[
              const Spacer(),
              IconButton(
                tooltip: 'Attach File',
                icon: const Icon(Icons.attach_file),
                onPressed: _pickAttachments,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in note.attachments)
              if (_isEditing)
                InputChip(
                  label: Text(
                    a.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: () {
                    setState(() {
                      _draftAttachments = _draftAttachments
                          .where((x) => x.name != a.name)
                          .toList();
                    });
                  },
                )
              else
                ActionChip(
                  label: Text(
                    a.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _openAttachment(a),
                ),
          ],
        ),
        if (_isEditing)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _draftAttachments)
                if (!note.attachments.any((x) => x.name == a.name))
                  InputChip(
                    label: Text(
                      a.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: () {
                      setState(() {
                        _draftAttachments = _draftAttachments
                            .where((x) => x.name != a.name)
                            .toList();
                      });
                    },
                  ),
            ],
          ),
      ],
    );
  }

  Widget _buildMetaSection(Note note) {
    final created = note.createdAt;
    final updated = note.updatedAt;
    final scheduled = note.scheduledDelete;

    final createdLabel = created.toLocal().toString().split('.').first;
    final updatedLabel = updated.toLocal().toString().split('.').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Created: $createdLabel'),
        if (updated != created) Text('Updated: $updatedLabel'),
        if (scheduled != null)
          Text(
            'Delete scheduled: ${scheduled.toLocal().toString().split('.').first}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Note' : 'View Note'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading ? null : widget.onBack,
        ),
        actions: [
          if (note != null && !_isEditing)
            IconButton(
              tooltip: note.isLocked ? 'Remove Lock' : 'Lock Note',
              icon: Icon(note.isLocked ? Icons.lock_open : Icons.lock),
              onPressed: () {
                setState(() => _pinModalOpen = true);
              },
            ),
          if (note != null && !_isEditing)
            IconButton(
              tooltip: 'Schedule Delete',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () {
                setState(() => _scheduleModalOpen = true);
              },
            ),
          if (note != null && !_isEditing)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                if (note.isLocked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unlock to edit this note')),
                  );
                  return;
                }
                setState(() => _isEditing = true);
              },
            ),
          if (note != null && !_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteNote,
            ),
          if (_isEditing)
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: () {
                _titleController.text = note?.title ?? '';
                _contentController.text = note?.contentDeltaJson ?? '';
                _draftAttachments =
                    List<NoteAttachment>.from(note?.attachments ?? []);
                setState(() => _isEditing = false);
              },
            ),
          if (_isEditing)
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.save_outlined),
              onPressed: _save,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : note == null
              ? const SizedBox.shrink()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing)
                              TextField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  hintText: 'Note title',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            if (_isEditing) const SizedBox(height: 12),
                            if (_isEditing)
                              Expanded(
                                child: TextField(
                                  controller: _contentController,
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  decoration: const InputDecoration(
                                    hintText: 'Start writing...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      Text(
                                        note.title,
                                        style:
                                            Theme.of(context).textTheme.headlineSmall,
                                      ),
                                      const SizedBox(height: 8),
                                      if (note.isLocked)
                                        const Text(
                                          '🔒 Locked content',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      const SizedBox(height: 8),
                                      if (note.contentDeltaJson.trim().isNotEmpty)
                                        Text(
                                          note.contentDeltaJson,
                                          style:
                                              Theme.of(context).textTheme.bodyLarge,
                                        ),
                                      const SizedBox(height: 16),
                                      _buildAttachmentsSection(note),
                                      const SizedBox(height: 16),
                                      _buildMetaSection(note),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_pinModalOpen)
                      Positioned.fill(
                        child: PinLockModal(
                          isOpen: true,
                          mode: note.isLocked
                              ? PinLockMode.verify
                              : PinLockMode.set,
                          correctPin: note.pin,
                          onSetSuccess: (pin) async {
                            await _applyLockFromPin(pin);
                            setState(() => _pinModalOpen = false);
                          },
                          onVerified: () async {
                            await _unlockWithPinSuccess();
                            setState(() => _pinModalOpen = false);
                          },
                          onClosed: () {
                            setState(() => _pinModalOpen = false);
                          },
                        ),
                      ),
                    if (_scheduleModalOpen)
                      Positioned.fill(
                        child: ScheduleDeleteModal(
                          isOpen: true,
                          currentScheduleIso: note.scheduledDeleteIso,
                          onSchedule: (when) async {
                            await _setSchedule(when);
                          },
                          onClose: () =>
                              setState(() => _scheduleModalOpen = false),
                        ),
                      ),
                  ],
                ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
