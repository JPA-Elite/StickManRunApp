import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router';
import { Toaster } from 'sonner';
import { ThemeProvider } from './context/ThemeContext';
import { TabNavigation } from './components/TabNavigation';
import { CreateNote } from './components/CreateNote';
import { NotesList } from './components/NotesList';
import { NoteDetail } from './components/NoteDetail';
import { Settings } from './components/Settings';
import { PrivacyPolicy } from './components/PrivacyPolicy';

function AppContent() {
  const location = useLocation();
  const hideTabsOnPaths = ['/privacy'];
  const hideTabsOnPatterns = [/^\/notes\/[^/]+$/];

  const shouldHideTabs = hideTabsOnPaths.includes(location.pathname) ||
    hideTabsOnPatterns.some(pattern => pattern.test(location.pathname));

  return (
    <div className="size-full flex items-center justify-center bg-gray-50 dark:bg-gray-900">
      <div className="w-full h-full max-w-md bg-white dark:bg-gray-800 shadow-xl flex flex-col">
        <div className="flex-1 overflow-y-auto">
          <Routes>
            <Route path="/" element={<Navigate to="/notes" replace />} />
            <Route path="/notes" element={<NotesList />} />
            <Route path="/notes/:id" element={<NoteDetail />} />
            <Route path="/create" element={<CreateNote />} />
            <Route path="/settings" element={<Settings />} />
            <Route path="/privacy" element={<PrivacyPolicy />} />
          </Routes>
        </div>
        {!shouldHideTabs && <TabNavigation />}
      </div>
    </div>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <BrowserRouter>
        <AppContent />
        <Toaster position="top-center" />
      </BrowserRouter>
    </ThemeProvider>
  );
}