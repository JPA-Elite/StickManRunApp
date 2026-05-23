import { useRef, useState, useEffect } from 'react';
import {
  Bold,
  Italic,
  Underline,
  List,
  ListOrdered,
  AlignLeft,
  AlignCenter,
  AlignRight,
  Heading1,
  Heading2,
  Type,
} from 'lucide-react';

interface RichTextEditorProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}

export function RichTextEditor({ value, onChange, placeholder }: RichTextEditorProps) {
  const editorRef = useRef<HTMLDivElement>(null);
  const [fontSize, setFontSize] = useState('16');

  useEffect(() => {
    if (editorRef.current && value !== editorRef.current.innerHTML) {
      editorRef.current.innerHTML = value;
    }
  }, [value]);

  const execCommand = (command: string, value?: string) => {
    document.execCommand(command, false, value);
    editorRef.current?.focus();
    updateContent();
  };

  const updateContent = () => {
    if (editorRef.current) {
      onChange(editorRef.current.innerHTML);
    }
  };

  const handleFontSize = (size: string) => {
    setFontSize(size);
    if (editorRef.current) {
      const selection = window.getSelection();
      if (selection && !selection.isCollapsed) {
        execCommand('fontSize', '7');
        const fontElements = editorRef.current.querySelectorAll('font[size="7"]');
        fontElements.forEach((element) => {
          const span = document.createElement('span');
          span.style.fontSize = size + 'px';
          span.innerHTML = element.innerHTML;
          element.parentNode?.replaceChild(span, element);
        });
        updateContent();
      }
    }
  };

  const toolbarButtons = [
    {
      icon: Bold,
      command: 'bold',
      tooltip: 'Bold',
    },
    {
      icon: Italic,
      command: 'italic',
      tooltip: 'Italic',
    },
    {
      icon: Underline,
      command: 'underline',
      tooltip: 'Underline',
    },
    {
      icon: Heading1,
      command: 'formatBlock',
      value: 'h1',
      tooltip: 'Heading 1',
    },
    {
      icon: Heading2,
      command: 'formatBlock',
      value: 'h2',
      tooltip: 'Heading 2',
    },
    {
      icon: List,
      command: 'insertUnorderedList',
      tooltip: 'Bullet List',
    },
    {
      icon: ListOrdered,
      command: 'insertOrderedList',
      tooltip: 'Numbered List',
    },
    {
      icon: AlignLeft,
      command: 'justifyLeft',
      tooltip: 'Align Left',
    },
    {
      icon: AlignCenter,
      command: 'justifyCenter',
      tooltip: 'Align Center',
    },
    {
      icon: AlignRight,
      command: 'justifyRight',
      tooltip: 'Align Right',
    },
  ];

  return (
    <div className="flex flex-col h-full border border-gray-300 dark:border-gray-600 rounded-lg overflow-hidden bg-white dark:bg-gray-700">
      <div className="border-b border-gray-300 dark:border-gray-600 p-2 flex flex-wrap gap-1 bg-gray-50 dark:bg-gray-800">
        <div className="flex items-center gap-1 mr-2 pr-2 border-r border-gray-300 dark:border-gray-600">
          <Type className="w-4 h-4 text-gray-600 dark:text-gray-400" />
          <select
            value={fontSize}
            onChange={(e) => handleFontSize(e.target.value)}
            className="px-2 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="12">12px</option>
            <option value="14">14px</option>
            <option value="16">16px</option>
            <option value="18">18px</option>
            <option value="20">20px</option>
            <option value="24">24px</option>
            <option value="28">28px</option>
            <option value="32">32px</option>
          </select>
        </div>

        {toolbarButtons.map((button, index) => (
          <button
            key={index}
            onClick={() => execCommand(button.command, button.value)}
            className="p-2 hover:bg-gray-200 dark:hover:bg-gray-600 rounded transition-colors text-gray-700 dark:text-gray-300"
            title={button.tooltip}
            type="button"
          >
            <button.icon className="w-4 h-4" />
          </button>
        ))}
      </div>

      <div
        ref={editorRef}
        contentEditable
        onInput={updateContent}
        className="flex-1 p-4 focus:outline-none overflow-y-auto text-gray-900 dark:text-white"
        style={{ minHeight: '200px' }}
        data-placeholder={placeholder}
      />

      <style>{`
        [contenteditable]:empty:before {
          content: attr(data-placeholder);
          color: #9ca3af;
          pointer-events: none;
        }
        [contenteditable] h1 {
          font-size: 2em;
          font-weight: bold;
          margin: 0.5em 0;
        }
        [contenteditable] h2 {
          font-size: 1.5em;
          font-weight: bold;
          margin: 0.5em 0;
        }
        [contenteditable] ul, [contenteditable] ol {
          margin: 0.5em 0;
          padding-left: 2em;
        }
        [contenteditable] li {
          margin: 0.25em 0;
        }
      `}</style>
    </div>
  );
}
