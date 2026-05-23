import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { Search, Trash2, Edit3, Clock, Lock } from 'lucide-react';
import { toast } from 'sonner';
import { ProfileSection } from './ProfileSection';
import { PinLockModal } from './PinLockModal';

interface Note {
  id: string;
  title: string;
  content: string;
  createdAt: string;
  updatedAt: string;
  isLocked?: boolean;
  pin?: string;
  attachments?: Array<{ name: string; data: string; type: string }>;
  scheduledDelete?: string;
}

export function NotesList() {
  const navigate = useNavigate();
  const [notes, setNotes] = useState<Note[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedNoteId, setSelectedNoteId] = useState<string | null>(null);
  const [showPinModal, setShowPinModal] = useState(false);

  useEffect(() => {
    loadNotes();
    checkScheduledDeletes();

    // Check scheduled deletes every minute
    const interval = setInterval(checkScheduledDeletes, 60000);

    // Reload notes when navigating back to this page
    const handleFocus = () => {
      loadNotes();
      checkScheduledDeletes();
    };
    window.addEventListener('focus', handleFocus);

    return () => {
      clearInterval(interval);
      window.removeEventListener('focus', handleFocus);
    };
  }, []);

  const checkScheduledDeletes = () => {
    const storedNotes = JSON.parse(localStorage.getItem('notes') || '[]');
    const now = new Date();
    const updatedNotes = storedNotes.filter((note: Note) => {
      if (note.scheduledDelete && new Date(note.scheduledDelete) <= now) {
        toast.info(`Note "${note.title}" was automatically deleted`);
        return false;
      }
      return true;
    });

    if (updatedNotes.length !== storedNotes.length) {
      localStorage.setItem('notes', JSON.stringify(updatedNotes));
      setNotes(updatedNotes);
    }
  };

  const loadNotes = () => {
    const storedNotes = JSON.parse(localStorage.getItem('notes') || '[]');
    setNotes(storedNotes);
  };

  const deleteNote = (id: string) => {
    const updatedNotes = notes.filter(note => note.id !== id);
    localStorage.setItem('notes', JSON.stringify(updatedNotes));
    setNotes(updatedNotes);
    toast.success('Note deleted');
  };

  const handleNoteClick = (note: Note) => {
    if (note.isLocked) {
      setSelectedNoteId(note.id);
      setShowPinModal(true);
    } else {
      navigate(`/notes/${note.id}`);
    }
  };

  const handlePinSuccess = () => {
    if (selectedNoteId) {
      navigate(`/notes/${selectedNoteId}`);
      setSelectedNoteId(null);
    }
  };

  const filteredNotes = notes.filter(note =>
    note.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    note.content.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffInHours = (now.getTime() - date.getTime()) / (1000 * 60 * 60);

    if (diffInHours < 24) {
      return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
    } else if (diffInHours < 168) {
      return date.toLocaleDateString('en-US', { weekday: 'short' });
    } else {
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
  };

  return (
    <div className="flex flex-col h-full">
      <header className="bg-blue-600 dark:bg-blue-800 text-white p-4">
        <div className="flex items-center justify-between mb-4">
          <h1>My Notes</h1>
          <ProfileSection size="small" />
        </div>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-blue-300 dark:text-blue-400" />
          <input
            type="text"
            placeholder="Search notes..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 rounded-lg bg-blue-700 dark:bg-blue-900 text-white placeholder-blue-300 dark:placeholder-blue-400 focus:outline-none focus:ring-2 focus:ring-white"
          />
        </div>
      </header>

      <div className="flex-1 overflow-y-auto bg-white dark:bg-gray-800">
        {filteredNotes.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-gray-400 dark:text-gray-500 p-8">
            <Edit3 className="w-16 h-16 mb-4" />
            <p className="text-center">
              {searchQuery ? 'No notes found' : 'No notes yet. Create your first note!'}
            </p>
          </div>
        ) : (
          <div className="divide-y divide-gray-200 dark:divide-gray-700">
            {filteredNotes.map((note) => (
              <div key={note.id} className="p-4 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors">
                <div className="flex items-start justify-between gap-3">
                  <div
                    className="flex-1 min-w-0 cursor-pointer"
                    onClick={() => handleNoteClick(note)}
                  >
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="truncate dark:text-white">{note.title}</h3>
                      {note.isLocked && (
                        <Lock className="w-4 h-4 text-blue-600 dark:text-blue-400 flex-shrink-0" />
                      )}
                    </div>
                    <div
                      className="text-sm text-gray-600 dark:text-gray-400 line-clamp-2 mb-2"
                      dangerouslySetInnerHTML={{ __html: note.isLocked ? '🔒 Locked content' : note.content }}
                    />
                    <div className="flex items-center gap-3 text-xs text-gray-500 dark:text-gray-500">
                      <div className="flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        <span>{formatDate(note.updatedAt)}</span>
                      </div>
                      {note.attachments && note.attachments.length > 0 && (
                        <span className="text-blue-600 dark:text-blue-400">
                          📎 {note.attachments.length}
                        </span>
                      )}
                      {note.scheduledDelete && (
                        <span className="text-orange-600 dark:text-orange-400">
                          🕐 Scheduled
                        </span>
                      )}
                    </div>
                  </div>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      deleteNote(note.id);
                    }}
                    className="p-2 text-gray-400 hover:text-red-600 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedNoteId && (
        <PinLockModal
          isOpen={showPinModal}
          onClose={() => {
            setShowPinModal(false);
            setSelectedNoteId(null);
          }}
          onSuccess={handlePinSuccess}
          mode="verify"
          correctPin={notes.find(n => n.id === selectedNoteId)?.pin}
        />
      )}
    </div>
  );
}
