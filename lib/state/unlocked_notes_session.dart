class UnlockedNotesSession {
  UnlockedNotesSession._();

  static final Set<String> _unlockedIds = <String>{};

  static bool isUnlocked(String noteId) => _unlockedIds.contains(noteId);

  static void markUnlocked(String noteId) {
    _unlockedIds.add(noteId);
  }

  static void clearUnlocked(String noteId) {
    _unlockedIds.remove(noteId);
  }

  static void clear() {
    _unlockedIds.clear();
  }
}
