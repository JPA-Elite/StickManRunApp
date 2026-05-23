import { useState, useRef } from 'react';
import { useNavigate } from 'react-router';
import { Save, ArrowLeft, Paperclip, X } from 'lucide-react';
import { toast } from 'sonner';
import { RichTextEditor } from './RichTextEditor';

export function CreateNote() {
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [attachments, setAttachments] = useState<Array<{ name: string; data: string; type: string }>>([]);

  const handleSave = () => {
    const plainTextContent = content.replace(/<[^>]*>/g, '').trim();

    if (!title.trim() && !plainTextContent) {
      toast.error('Please add a title or content');
      return;
    }

    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    const newNote = {
      id: Date.now().toString(),
      title: title.trim() || 'Untitled Note',
      content: content,
      attachments: attachments,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    notes.unshift(newNote);
    localStorage.setItem('notes', JSON.stringify(notes));

    toast.success('Note saved successfully!');
    setTitle('');
    setContent('');
    setAttachments([]);
    navigate('/notes');
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

  return (
    <div className="flex flex-col h-full">
      <header className="bg-blue-600 dark:bg-blue-800 text-white p-4 flex items-center gap-3">
        <button
          onClick={() => navigate('/notes')}
          className="p-1 hover:bg-blue-700 dark:hover:bg-blue-900 rounded-full transition-colors"
        >
          <ArrowLeft className="w-6 h-6" />
        </button>
        <h1 className="flex-1">Create Note</h1>
        <button
          onClick={handleSave}
          className="flex items-center gap-2 bg-white dark:bg-gray-200 text-blue-600 dark:text-blue-700 px-4 py-2 rounded-lg hover:bg-blue-50 dark:hover:bg-gray-300 transition-colors"
        >
          <Save className="w-5 h-5" />
          <span>Save</span>
        </button>
      </header>

      <div className="flex-1 p-4 flex flex-col gap-4 bg-white dark:bg-gray-800 overflow-hidden">
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
      </div>
    </div>
  );
}
