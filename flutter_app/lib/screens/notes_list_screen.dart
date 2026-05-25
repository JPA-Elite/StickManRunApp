import 'dart:async';

import 'package:flutter/material.dart';

import '../data/notes_repository.dart';
import '../models/note.dart';
import '../state/theme_controller.dart';
import '../widgets/pin_lock_modal.dart';
import '../widgets/tab_navigation.dart';
import '../widgets/top_toast.dart';

class NotesListScreen extends StatefulWidget {
  final NotesRepository notesRepository;
  final ThemeController themeController;

  // Backward-compatible constructor params.
  // Some stale bundles/hot-reload paths may still try to create the screen
  // with these named parameters. Making them optional prevents
  // NoSuchMethodError at runtime.
  final VoidCallback? onCreate;
  final void Function(String id)? onOpenNote;

  const NotesListScreen({
    super.key,
    required this.notesRepository,
    required this.themeController,
    this.onCreate,
    this.onOpenNote,
  });

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Note> _notes = const [];
  bool _loading = true;

  Timer? _purgeTimer;

  String get _searchQuery => _searchController.text.trim();

  // PIN modal state
  String? _selectedLockedNoteId;
  bool _pinModalOpen = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _purgeTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _purgeExpired());
  }

  @override
  void dispose() {
    _purgeTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _purgeExpired() async {
    await widget.notesRepository.purgeExpiredScheduledDeletes();
    await _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    final notes = await widget.notesRepository.getNotes();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _deleteNote(String id) async {
    await widget.notesRepository.deleteNote(id);
    if (!mounted) return;
    TopToast.show(context, message: 'Note deleted');
    await _loadNotes();
  }

  String _contentToSearchText(String contentDeltaJson) {
    // Until flutter_quill is wired back in, CreateNoteScreen stores plain text
    // directly in contentDeltaJson.
    return contentDeltaJson;
  }

  List<Note> get _filteredNotes {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return _notes;

    return _notes.where((n) {
      if (n.title.toLowerCase().contains(q)) return true;
      final plain = _contentToSearchText(n.contentDeltaJson).toLowerCase();
      return plain.contains(q);
    }).toList();
  }

  String _formatRelativeUpdated(DateTime updatedAt) {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);

    if (diff.inHours < 24) {
      final local = updatedAt.toLocal();
      return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
    }

    if (diff.inDays < 7) {
      final local = updatedAt.toLocal();
      return '${local.weekday}'; // simple fallback
    }

    final local = updatedAt.toLocal();
    return '${local.month}/${local.day}';
  }

  Future<void> _openNoteAndRefresh(String id) async {
    await Navigator.of(context).pushNamed('/note', arguments: id);
    if (!mounted) return;
    await _loadNotes();
  }

  Future<void> _unlockNoteFromList(String id) async {
    final existing = _notes.where((n) => n.id == id).cast<Note?>().firstOrNull;
    if (existing == null) return;

    final now = DateTime.now();

    final updated = Note(
      id: existing.id,
      title: existing.title,
      contentDeltaJson: existing.contentDeltaJson,
      createdAt: existing.createdAt,
      updatedAt: now,
      attachments: List<NoteAttachment>.from(existing.attachments),
      isLocked: false,
      pin: null,
      scheduledDeleteIso: existing.scheduledDeleteIso,
    );

    await widget.notesRepository.updateNote(updated);
    await _loadNotes();
  }

  void _createAndRefresh() {
    Navigator.of(context).pushNamed('/create').then((_) async {
      if (!mounted) return;
      await _loadNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lockedId = _selectedLockedNoteId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Create',
            onPressed: _createAndRefresh,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredNotes.isEmpty
                      ? _EmptyState(searching: _searchQuery.isNotEmpty)
                      : RefreshIndicator(
                          onRefresh: _loadNotes,
                          child: ListView.separated(
                            itemCount: _filteredNotes.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 0),
                            itemBuilder: (context, index) {
                              final note = _filteredNotes[index];

                              return InkWell(
                                onTap: () async {
                                  if (note.isLocked) {
                                    setState(() {
                                      _selectedLockedNoteId = note.id;
                                      _pinModalOpen = true;
                                    });
                                    return;
                                  }

                                  await _openNoteAndRefresh(note.id);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    note.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                if (note.isLocked)
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 8),
                                                    child: Icon(Icons.lock,
                                                        size: 18),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              note.isLocked
                                                  ? '🔒 Locked content'
                                                  : _contentToSearchText(
                                                          note.contentDeltaJson)
                                                      .trim(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme
                                                    .colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _formatRelativeUpdated(
                                                      note.updatedAt),
                                                  style: theme.textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (note.attachments
                                                    .isNotEmpty)
                                                  Text(
                                                    '📎 ${note.attachments.length}',
                                                    style: theme.textTheme
                                                        .bodySmall,
                                                  ),
                                                if (note.hasScheduledDelete)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      left: 10,
                                                    ),
                                                    child: Text(
                                                      '🕐 Scheduled',
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color: Colors.orange,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Delete Note?'),
                                              content: const Text(
                                                'Are you sure you want to delete this note?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                          context)
                                                      .pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                          context)
                                                      .pop(true),
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true) {
                                            await _deleteNote(note.id);
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: TabNavigation(
          active: TabRoute.notes,
          onNotes: () {},
          onReminders: () => Navigator.of(context).pushNamed('/reminders'),
          onSettings: () {
            Navigator.of(context).pushNamed('/settings');
          },
        ),
      ),
      bottomSheet: _pinModalOpen
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: PinLockModal(
                isOpen: true,
                mode: PinLockMode.verify,
                correctPin: _notes
                    .where((n) => n.id == _selectedLockedNoteId)
                    .cast<Note?>()
                    .firstOrNull
                    ?.pin,
                onVerified: () async {
                  final id = _selectedLockedNoteId;
                  setState(() {
                    _pinModalOpen = false;
                    _selectedLockedNoteId = null;
                  });

                  if (id == null) return;

                  // Persist unlock so the note is no longer marked locked.
                  await _unlockNoteFromList(id);

                  if (!mounted) return;

                  // Navigate using the same path as unlocked notes.
                  await _openNoteAndRefresh(id);
                },
                onClosed: () {
                  setState(() {
                    _pinModalOpen = false;
                    _selectedLockedNoteId = null;
                  });
                },
              ),
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool searching;

  const _EmptyState({required this.searching});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              searching ? 'No notes found' : 'No notes yet. Create your first note!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
