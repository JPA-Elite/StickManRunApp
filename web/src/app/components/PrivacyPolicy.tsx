import { useNavigate } from 'react-router';
import { Shield, Lock, Eye, Database, UserCheck, ArrowLeft } from 'lucide-react';

export function PrivacyPolicy() {
  const navigate = useNavigate();

  return (
    <div className="flex flex-col h-full">
      <header className="bg-blue-600 dark:bg-blue-800 text-white p-4">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate('/settings')}
            className="p-1 hover:bg-blue-700 dark:hover:bg-blue-900 rounded-full transition-colors"
          >
            <ArrowLeft className="w-6 h-6" />
          </button>
          <h1>Privacy Policy</h1>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto p-4 bg-white dark:bg-gray-800">
        <div className="space-y-6">
          <section className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 bg-blue-600 dark:bg-blue-700 rounded-full flex items-center justify-center">
                <Shield className="w-6 h-6 text-white" />
              </div>
              <h2 className="dark:text-white">Your Privacy Matters</h2>
            </div>
            <p className="text-sm text-gray-700 dark:text-gray-300">
              We are committed to protecting your privacy. This policy explains how we handle your data.
            </p>
          </section>

          <section>
            <div className="flex items-center gap-3 mb-3">
              <div className="w-8 h-8 bg-green-100 dark:bg-green-900 rounded-full flex items-center justify-center">
                <Database className="w-5 h-5 text-green-600 dark:text-green-400" />
              </div>
              <h3 className="dark:text-white">Data Storage</h3>
            </div>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">
              All your notes are stored locally on your device using browser storage. We do not have access to your notes.
            </p>
            <ul className="text-sm text-gray-600 dark:text-gray-400 space-y-1 ml-4">
              <li>• Notes remain on your device only</li>
              <li>• No cloud synchronization</li>
              <li>• You control your data</li>
            </ul>
          </section>

          <section>
            <div className="flex items-center gap-3 mb-3">
              <div className="w-8 h-8 bg-purple-100 dark:bg-purple-900 rounded-full flex items-center justify-center">
                <Lock className="w-5 h-5 text-purple-600 dark:text-purple-400" />
              </div>
              <h3 className="dark:text-white">Data Security</h3>
            </div>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">
              Your data security is important to us:
            </p>
            <ul className="text-sm text-gray-600 dark:text-gray-400 space-y-1 ml-4">
              <li>• No data transmitted to external servers</li>
              <li>• Local encryption in browser storage</li>
              <li>• No third-party tracking</li>
              <li>• No analytics or cookies</li>
            </ul>
          </section>

          <section>
            <div className="flex items-center gap-3 mb-3">
              <div className="w-8 h-8 bg-orange-100 dark:bg-orange-900 rounded-full flex items-center justify-center">
                <Eye className="w-5 h-5 text-orange-600 dark:text-orange-400" />
              </div>
              <h3 className="dark:text-white">Information We Collect</h3>
            </div>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">
              We collect minimal information:
            </p>
            <ul className="text-sm text-gray-600 dark:text-gray-400 space-y-1 ml-4">
              <li>• Note content (stored locally only)</li>
              <li>• App preferences and settings</li>
              <li>• No personal identification data</li>
              <li>• No location tracking</li>
            </ul>
          </section>

          <section>
            <div className="flex items-center gap-3 mb-3">
              <div className="w-8 h-8 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center">
                <UserCheck className="w-5 h-5 text-blue-600 dark:text-blue-400" />
              </div>
              <h3 className="dark:text-white">Your Rights</h3>
            </div>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">
              You have full control over your data:
            </p>
            <ul className="text-sm text-gray-600 dark:text-gray-400 space-y-1 ml-4">
              <li>• Export all notes at any time</li>
              <li>• Delete all data permanently</li>
              <li>• No account required</li>
              <li>• Complete data ownership</li>
            </ul>
          </section>

          <section className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-4 border border-gray-200 dark:border-gray-600">
            <h3 className="mb-2 dark:text-white">Contact</h3>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              If you have any questions about this privacy policy or your data, please contact us at{' '}
              <a href="mailto:privacy@notesapp.com" className="text-blue-600 dark:text-blue-400 underline">
                privacy@notesapp.com
              </a>
            </p>
          </section>

          <p className="text-xs text-gray-500 dark:text-gray-500 text-center pb-4">
            Last updated: May 22, 2026
          </p>
        </div>
      </div>
    </div>
  );
}
