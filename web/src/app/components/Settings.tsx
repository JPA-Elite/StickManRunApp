import { useState } from 'react';
import { useNavigate } from 'react-router';
import { ChevronRight, Moon, Bell, Download, Trash2, Info, Shield } from 'lucide-react';
import { toast } from 'sonner';
import { ProfileSection } from './ProfileSection';
import { ConfirmModal } from './ConfirmModal';
import { useTheme } from '../context/ThemeContext';

export function Settings() {
  const navigate = useNavigate();
  const { darkMode, toggleDarkMode } = useTheme();
  const [notifications, setNotifications] = useState(true);
  const [showClearModal, setShowClearModal] = useState(false);

  const handleExport = () => {
    const notes = localStorage.getItem('notes') || '[]';
    const blob = new Blob([notes], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `notes-backup-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
    toast.success('Notes exported successfully!');
  };

  const handleClearAll = () => {
    localStorage.removeItem('notes');
    toast.success('All notes deleted');
  };

  return (
    <div className="flex flex-col h-full">
      <header className="bg-blue-600 text-white p-4">
        <h1>Settings</h1>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="bg-gradient-to-br from-blue-600 to-purple-600 p-8 flex justify-center">
          <ProfileSection showName={true} size="large" editable={true} />
        </div>
        <div className="p-4 space-y-6">
          <section>
            <h2 className="text-sm text-gray-500 dark:text-gray-400 mb-3">Appearance</h2>
            <div className="bg-white dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600 divide-y divide-gray-200 dark:divide-gray-600">
              <div className="flex items-center justify-between p-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center">
                    <Moon className="w-5 h-5 text-blue-600 dark:text-blue-300" />
                  </div>
                  <div>
                    <p className="dark:text-white">Dark Mode</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      {darkMode ? 'Enabled' : 'Disabled'}
                    </p>
                  </div>
                </div>
                <label className="relative inline-block w-12 h-6">
                  <input
                    type="checkbox"
                    checked={darkMode}
                    onChange={toggleDarkMode}
                    className="sr-only peer"
                  />
                  <div className="w-full h-full bg-gray-300 dark:bg-gray-600 rounded-full peer-checked:bg-blue-600 transition-colors cursor-pointer"></div>
                  <div className="absolute left-1 top-1 w-4 h-4 bg-white rounded-full transition-transform peer-checked:translate-x-6"></div>
                </label>
              </div>
            </div>
          </section>

          <section>
            <h2 className="text-sm text-gray-500 dark:text-gray-400 mb-3">Notifications</h2>
            <div className="bg-white dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600 divide-y divide-gray-200 dark:divide-gray-600">
              <div className="flex items-center justify-between p-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-full flex items-center justify-center">
                    <Bell className="w-5 h-5 text-green-600 dark:text-green-300" />
                  </div>
                  <div>
                    <p className="dark:text-white">Push Notifications</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">Get notified about reminders</p>
                  </div>
                </div>
                <label className="relative inline-block w-12 h-6">
                  <input
                    type="checkbox"
                    checked={notifications}
                    onChange={(e) => setNotifications(e.target.checked)}
                    className="sr-only peer"
                  />
                  <div className="w-full h-full bg-gray-300 dark:bg-gray-600 rounded-full peer-checked:bg-blue-600 transition-colors"></div>
                  <div className="absolute left-1 top-1 w-4 h-4 bg-white rounded-full transition-transform peer-checked:translate-x-6"></div>
                </label>
              </div>
            </div>
          </section>

          <section>
            <h2 className="text-sm text-gray-500 dark:text-gray-400 mb-3">Data</h2>
            <div className="bg-white dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600 divide-y divide-gray-200 dark:divide-gray-600">
              <button
                onClick={handleExport}
                className="flex items-center justify-between p-4 w-full hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center">
                    <Download className="w-5 h-5 text-blue-600 dark:text-blue-300" />
                  </div>
                  <div className="text-left">
                    <p className="dark:text-white">Export Notes</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">Download backup file</p>
                  </div>
                </div>
                <ChevronRight className="w-5 h-5 text-gray-400 dark:text-gray-500" />
              </button>

              <button
                onClick={() => setShowClearModal(true)}
                className="flex items-center justify-between p-4 w-full hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-red-100 dark:bg-red-900 rounded-full flex items-center justify-center">
                    <Trash2 className="w-5 h-5 text-red-600 dark:text-red-400" />
                  </div>
                  <div className="text-left">
                    <p className="text-red-600 dark:text-red-400">Clear All Notes</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">Delete all saved notes</p>
                  </div>
                </div>
                <ChevronRight className="w-5 h-5 text-gray-400 dark:text-gray-500" />
              </button>
            </div>
          </section>

          <section>
            <h2 className="text-sm text-gray-500 dark:text-gray-400 mb-3">Legal & About</h2>
            <div className="bg-white dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600 divide-y divide-gray-200 dark:divide-gray-600">
              <button
                onClick={() => navigate('/privacy')}
                className="flex items-center justify-between p-4 w-full hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center">
                    <Shield className="w-5 h-5 text-blue-600 dark:text-blue-300" />
                  </div>
                  <div className="text-left">
                    <p className="dark:text-white">Privacy Policy</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">How we handle your data</p>
                  </div>
                </div>
                <ChevronRight className="w-5 h-5 text-gray-400 dark:text-gray-500" />
              </button>

              <div className="flex items-center justify-between p-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-purple-100 dark:bg-purple-900 rounded-full flex items-center justify-center">
                    <Info className="w-5 h-5 text-purple-600 dark:text-purple-300" />
                  </div>
                  <div>
                    <p className="dark:text-white">Version</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">1.0.0</p>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </div>
      </div>

      <ConfirmModal
        isOpen={showClearModal}
        onClose={() => setShowClearModal(false)}
        onConfirm={handleClearAll}
        title="Delete All Notes?"
        message="Are you sure you want to delete all notes? This action cannot be undone and all your notes will be permanently removed."
        confirmText="Delete All"
        cancelText="Cancel"
        type="danger"
      />
    </div>
  );
}
