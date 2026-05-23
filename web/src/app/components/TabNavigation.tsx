import { useLocation, useNavigate } from 'react-router';
import { FileText, PlusCircle, Settings } from 'lucide-react';

export function TabNavigation() {
  const location = useLocation();
  const navigate = useNavigate();

  const tabs = [
    { path: '/notes', icon: FileText, label: 'Notes' },
    { path: '/create', icon: PlusCircle, label: 'Create' },
    { path: '/settings', icon: Settings, label: 'Settings' },
  ];

  return (
    <nav className="border-t border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800">
      <div className="grid grid-cols-3">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = location.pathname === tab.path;

          return (
            <button
              key={tab.path}
              onClick={() => navigate(tab.path)}
              className={`flex flex-col items-center gap-1 py-3 transition-colors ${
                isActive
                  ? 'text-blue-600 dark:text-blue-400'
                  : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'
              }`}
            >
              <Icon className="w-6 h-6" />
              <span className="text-xs">{tab.label}</span>
            </button>
          );
        })}
      </div>
    </nav>
  );
}
