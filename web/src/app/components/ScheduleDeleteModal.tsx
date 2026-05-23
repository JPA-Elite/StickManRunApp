import { useState } from 'react';
import { X, Calendar, Clock } from 'lucide-react';

interface ScheduleDeleteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSchedule: (date: Date) => void;
  currentSchedule?: string | null;
}

export function ScheduleDeleteModal({ isOpen, onClose, onSchedule, currentSchedule }: ScheduleDeleteModalProps) {
  const [selectedDate, setSelectedDate] = useState('');
  const [selectedTime, setSelectedTime] = useState('');

  const handleSchedule = () => {
    if (!selectedDate || !selectedTime) return;

    const dateTime = new Date(`${selectedDate}T${selectedTime}`);
    if (dateTime <= new Date()) {
      alert('Please select a future date and time');
      return;
    }

    onSchedule(dateTime);
    onClose();
    setSelectedDate('');
    setSelectedTime('');
  };

  const handleRemove = () => {
    onSchedule(null as any);
    onClose();
  };

  if (!isOpen) return null;

  const formatScheduledDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="absolute inset-0 bg-black/50 dark:bg-black/70"
        onClick={onClose}
      />

      <div className="relative bg-white dark:bg-gray-800 rounded-2xl shadow-2xl max-w-sm w-full p-6 animate-in fade-in zoom-in duration-200">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 rounded-full hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="flex flex-col items-center text-center">
          <div className="w-16 h-16 bg-orange-100 dark:bg-orange-900/30 rounded-full flex items-center justify-center mb-4">
            <Calendar className="w-8 h-8 text-orange-600 dark:text-orange-400" />
          </div>

          <h2 className="mb-2 dark:text-white">Schedule Delete</h2>
          <p className="text-sm text-gray-600 dark:text-gray-400 mb-6">
            Set when this note should be automatically deleted
          </p>

          {currentSchedule && (
            <div className="w-full mb-4 p-3 bg-orange-50 dark:bg-orange-900/20 border border-orange-200 dark:border-orange-800 rounded-lg">
              <p className="text-sm text-orange-800 dark:text-orange-300">
                Currently scheduled for:
              </p>
              <p className="text-sm font-medium text-orange-900 dark:text-orange-200">
                {formatScheduledDate(currentSchedule)}
              </p>
            </div>
          )}

          <div className="w-full space-y-4">
            <div>
              <label className="block text-left text-sm text-gray-700 dark:text-gray-300 mb-2">
                <Calendar className="w-4 h-4 inline mr-1" />
                Date
              </label>
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                min={new Date().toISOString().split('T')[0]}
                className="w-full px-4 py-2.5 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              />
            </div>

            <div>
              <label className="block text-left text-sm text-gray-700 dark:text-gray-300 mb-2">
                <Clock className="w-4 h-4 inline mr-1" />
                Time
              </label>
              <input
                type="time"
                value={selectedTime}
                onChange={(e) => setSelectedTime(e.target.value)}
                className="w-full px-4 py-2.5 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              />
            </div>
          </div>

          <div className="flex gap-3 w-full mt-6">
            {currentSchedule && (
              <button
                onClick={handleRemove}
                className="flex-1 px-4 py-2.5 border border-red-300 dark:border-red-600 text-red-600 dark:text-red-400 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
              >
                Remove
              </button>
            )}
            <button
              onClick={onClose}
              className="flex-1 px-4 py-2.5 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSchedule}
              disabled={!selectedDate || !selectedTime}
              className="flex-1 px-4 py-2.5 bg-blue-600 hover:bg-blue-700 dark:bg-blue-700 dark:hover:bg-blue-800 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Schedule
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
