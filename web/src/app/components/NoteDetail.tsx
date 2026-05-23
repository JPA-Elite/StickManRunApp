import { useState, useEffect, useRef } from 'react';
import { useNavigate, useParams } from 'react-router';
import { ArrowLeft, Save, Trash2, Edit3, Lock, Unlock, Calendar, Paperclip, Download, X } from 'lucide-react';
import { toast } from 'sonner';
import { RichTextEditor } from './RichTextEditor';
import { ConfirmModal } from './ConfirmModal';
import { PinLockModal } from './PinLockModal';
import { ScheduleDeleteModal } from './ScheduleDeleteModal';

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

export function NoteDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [note, setNote] = useState<Note | null>(null);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [isEditing, setIsEditing] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showPinModal, setShowPinModal] = useState(false);
  const [showScheduleModal, setShowScheduleModal] = useState(false);
  const [attachments, setAttachments] = useState<Array<{ name: string; data: string; type: string }>>([]);

  useEffect(() => {
    loadNote();
  }, [id]);

  const loadNote = () => {
    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    const foundNote = notes.find((n: Note) => n.id === id);
    if (foundNote) {
      setNote(foundNote);
      setTitle(foundNote.title);
      setContent(foundNote.content);
      setAttachments(foundNote.attachments || []);
    } else {
      toast.error('Note not found');
      navigate('/notes');
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files) return;

    Array.from(files).forEach((file) => {
      if (file.size > 10 * 1024 * 1024) {
        toast.error(`${file.name} is too large. Max size is 10MB`);
        return;
      }

      const reader = new FileReader();
      reader.onloadend = () => {
        const newAttachment = {
          name: file.name,
          data: reader.result as string,
          type: file.type,
        };
        setAttachments((prev) => [...prev, newAttachment]);
      };
      reader.readAsDataURL(file);
    });

    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const removeAttachment = (index: number) => {
    setAttachments((prev) => prev.filter((_, i) => i !== index));
  };

  const downloadAttachment = (attachment: { name: string; data: string; type: string }) => {
    const link = document.createElement('a');
    link.href = attachment.data;
    link.download = attachment.name;
    link.click();
  };

  const handleSave = () => {
    const plainTextContent = content.replace(/<[^>]*>/g, '').trim();

    if (!title.trim() && !plainTextContent) {
      toast.error('Please add a title or content');
      return;
    }

    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    const updatedNotes = notes.map((n: Note) =>
      n.id === id
        ? {
            ...n,
            title: title.trim() || 'Untitled Note',
            content: content,
            attachments: attachments,
            updatedAt: new Date().toISOString(),
          }
        : n
    );

    localStorage.setItem('notes', JSON.stringify(updatedNotes));
    toast.success('Note updated successfully!');
    setIsEditing(false);
    loadNote();
  };

  const handleToggleLock = () => {
    setShowPinModal(true);
  };

  const handleSetPin = (pin: string) => {
    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    const updatedNotes = notes.map((n: Note) =>
      n.id === id
        ? {
            ...n,
            isLocked: !n.isLocked,
            pin: !n.isLocked ? pin : undefined,
          }
        : n
    );

    localStorage.setItem('notes', JSON.stringify(updatedNotes));
    toast.success(note?.isLocked ? 'Lock removed' : 'Note locked');
    loadNote();
  };

  const handleScheduleDelete = (date: Date | null) => {
    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    const updatedNotes = notes.map((n: Note) =>
      n.id === id
        ? {
            ...n,
            scheduledDelete: date ? date.toISOString() : undefined,
          }
        : n
    );

    localStorage.setItem('notes', JSON.stringify(updatedNotes));
    toast.success(date ? 'Delete scheduled' : 'Schedule removed');
    loadNote();
  };

  const handleDelete = () => {
    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    const updatedNotes = notes.filter((n: Note) => n.id !== id);
    localStorage.setItem('notes', JSON.stringify(updatedNotes));
    toast.success('Note deleted');
    navigate('/notes');
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  };

  if (!note) {
    return null;
  }

  return (
    <div className="flex flex-col h-full">
      <header className="bg-blue-600 dark:bg-blue-800 text-white p-4 flex items-center gap-3">
        <button
          onClick={() => navigate('/notes')}
          className="p-1 hover:bg-blue-700 dark:hover:bg-blue-900 rounded-full transition-colors"
        >
          <ArrowLeft className="w-6 h-6" />
        </button>
        <h1 className="flex-1">{isEditing ? 'Edit Note' : 'View Note'}</h1>

        <div className="flex items-center gap-2">
          {isEditing ? (
            <>
              <button
                onClick={() => {
                  setIsEditing(false);
                  setTitle(note.title);
                  setContent(note.content);
                  setAttachments(note.attachments || []);
                }}
                className="px-3 py-2 text-white hover:bg-blue-700 dark:hover:bg-blue-900 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                className="flex items-center gap-2 bg-white dark:bg-gray-200 text-blue-600 dark:text-blue-700 px-4 py-2 rounded-lg hover:bg-blue-50 dark:hover:bg-gray-300 transition-colors"
              >
                <Save className="w-5 h-5" />
                <span>Save</span>
              </button>
            </>
          ) : (
            <>
              <button
                onClick={handleToggleLock}
                className="p-2 hover:bg-blue-700 dark:hover:bg-blue-900 rounded-full transition-colors"
                title={note.isLocked ? 'Remove Lock' : 'Lock Note'}
              >
                {note.isLocked ? <Unlock className="w-5 h-5" /> : <Lock className="w-5 h-5" />}
              </button>
              <button
                onClick={() => setShowScheduleModal(true)}
                className="p-2 hover:bg-blue-700 dark:hover:bg-blue-900 rounded-full transition-colors"
                title="Schedule Delete"
              >
                <Calendar className="w-5 h-5" />
              </button>
              <button
                onClick={() => setIsEditing(true)}
                className="p-2 hover:bg-blue-700 dark:hover:bg-blue-900 rounded-full transition-colors"
                title="Edit"
              >
                <Edit3 className="w-5 h-5" />
              </button>
              <button
                onClick={() => setShowDeleteModal(true)}
                className="p-2 hover:bg-blue-700 dark:hover:bg-blue-900 rounded-full transition-colors"
                title="Delete"
              >
                <Trash2 className="w-5 h-5" />
              </button>
            </>
          )}
        </div>
      </header>

      <div className="flex-1 p-4 flex flex-col gap-4 bg-white dark:bg-gray-800 overflow-hidden">
        {isEditing ? (
          <>
            <input
              type="text"
              placeholder="Note title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400"
            />

            <div className="flex items-center gap-2">
              <button
                onClick={() => fileInputRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
              >
                <Paperclip className="w-4 h-4" />
                <span className="text-sm">Attach File</span>
              </button>
              <input
                ref={fileInputRef}
                type="file"
                multiple
                onChange={handleFileUpload}
                className="hidden"
              />
            </div>

            {attachments.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {attachments.map((file, index) => (
                  <div
                    key={index}
                    className="flex items-center gap-2 px-3 py-1.5 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg text-sm"
                  >
                    <Paperclip className="w-3 h-3 text-blue-600 dark:text-blue-400" />
                    <span className="text-blue-900 dark:text-blue-200 max-w-[150px] truncate">
                      {file.name}
                    </span>
                    <button
                      onClick={() => removeAttachment(index)}
                      className="text-blue-600 dark:text-blue-400 hover:text-red-600 dark:hover:text-red-400"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                ))}
              </div>
            )}

            <RichTextEditor
              value={content}
              onChange={setContent}
              placeholder="Start writing your note..."
            />
          </>
        ) : (
          <div className="flex-1 overflow-y-auto">
            <div className="mb-4">
              <div className="flex items-center gap-2 mb-2">
                <h2 className="dark:text-white">{note.title}</h2>
                {note.isLocked && (
                  <Lock className="w-5 h-5 text-blue-600 dark:text-blue-400" />
                )}
              </div>
              <div className="flex items-center gap-4 text-sm text-gray-500 dark:text-gray-400 flex-wrap">
                <span>Created: {formatDate(note.createdAt)}</span>
                {note.updatedAt !== note.createdAt && (
                  <span>Updated: {formatDate(note.updatedAt)}</span>
                )}
                {note.scheduledDelete && (
                  <span className="text-orange-600 dark:text-orange-400">
                    Delete: {formatDate(note.scheduledDelete)}
                  </span>
                )}
              </div>
            </div>

            {note.attachments && note.attachments.length > 0 && (
              <div className="mb-4">
                <h3 className="text-sm mb-2 dark:text-white">Attachments</h3>
                <div className="flex flex-wrap gap-2">
                  {note.attachments.map((file, index) => (
                    <button
                      key={index}
                      onClick={() => downloadAttachment(file)}
                      className="flex items-center gap-2 px-3 py-1.5 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg text-sm hover:bg-blue-100 dark:hover:bg-blue-900/30 transition-colors"
                    >
                      <Paperclip className="w-3 h-3 text-blue-600 dark:text-blue-400" />
                      <span className="text-blue-900 dark:text-blue-200 max-w-[150px] truncate">
                        {file.name}
                      </span>
                      <Download className="w-3 h-3 text-blue-600 dark:text-blue-400" />
                    </button>
                  ))}
                </div>
              </div>
            )}

            <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-4 border border-gray-200 dark:border-gray-600">
              <div
                className="prose prose-sm dark:prose-invert max-w-none text-gray-900 dark:text-white"
                dangerouslySetInnerHTML={{ __html: note.content }}
              />
            </div>
          </div>
        )}
      </div>

      <ConfirmModal
        isOpen={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
        onConfirm={handleDelete}
        title="Delete Note?"
        message="Are you sure you want to delete this note? This action cannot be undone."
        confirmText="Delete"
        cancelText="Cancel"
        type="danger"
      />

      <PinLockModal
        isOpen={showPinModal}
        onClose={() => setShowPinModal(false)}
        onSuccess={(pin) => {
          handleSetPin(pin);
          setShowPinModal(false);
        }}
        mode={note?.isLocked ? 'verify' : 'set'}
        correctPin={note?.pin}
      />

      <ScheduleDeleteModal
        isOpen={showScheduleModal}
        onClose={() => setShowScheduleModal(false)}
        onSchedule={handleScheduleDelete}
        currentSchedule={note?.scheduledDelete}
      />
    </div>
  );
}
