import { useState, useEffect } from 'react';
import { Lock, X, AlertCircle } from 'lucide-react';

interface PinLockModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: (pin?: string) => void;
  mode: 'set' | 'verify';
  correctPin?: string;
}

export function PinLockModal({ isOpen, onClose, onSuccess, mode, correctPin }: PinLockModalProps) {
  const [pin, setPin] = useState('');
  const [confirmPin, setConfirmPin] = useState('');
  const [attempts, setAttempts] = useState(0);
  const [cooldownUntil, setCooldownUntil] = useState<number | null>(null);
  const [error, setError] = useState('');
  const [step, setStep] = useState<'enter' | 'confirm'>('enter');

  useEffect(() => {
    if (cooldownUntil) {
      const interval = setInterval(() => {
        if (Date.now() >= cooldownUntil) {
          setCooldownUntil(null);
          setAttempts(0);
        }
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [cooldownUntil]);

  const getRemainingCooldown = () => {
    if (!cooldownUntil) return 0;
    return Math.ceil((cooldownUntil - Date.now()) / 1000);
  };

  const handleSubmit = () => {
    setError('');

    if (cooldownUntil && Date.now() < cooldownUntil) {
      setError(`Too many attempts. Please wait ${getRemainingCooldown()}s`);
      return;
    }

    if (pin.length < 6) {
      setError('PIN must be at least 6 digits');
      return;
    }

    if (mode === 'set') {
      if (step === 'enter') {
        setStep('confirm');
        setError('');
      } else {
        if (pin === confirmPin) {
          onSuccess(pin);
          resetModal();
        } else {
          setError('PINs do not match');
          setConfirmPin('');
        }
      }
    } else {
      // Verify mode
      if (pin === correctPin) {
        onSuccess();
        resetModal();
      } else {
        const newAttempts = attempts + 1;
        setAttempts(newAttempts);

        if (newAttempts >= 5) {
          setCooldownUntil(Date.now() + 30000);
          setError('Too many attempts. Locked for 30 seconds');
        } else {
          setError(`Incorrect PIN. ${5 - newAttempts} attempts remaining`);
        }
        setPin('');
      }
    }
  };

  const resetModal = () => {
    setPin('');
    setConfirmPin('');
    setError('');
    setStep('enter');
    setAttempts(0);
    setCooldownUntil(null);
    onClose();
  };

  const handlePinInput = (value: string) => {
    if (/^\d*$/.test(value) && value.length <= 10) {
      if (step === 'confirm') {
        setConfirmPin(value);
      } else {
        setPin(value);
      }
    }
  };

  if (!isOpen) return null;

  const isLocked = cooldownUntil && Date.now() < cooldownUntil;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="absolute inset-0 bg-black/50 dark:bg-black/70"
        onClick={resetModal}
      />

      <div className="relative bg-white dark:bg-gray-800 rounded-2xl shadow-2xl max-w-sm w-full p-6 animate-in fade-in zoom-in duration-200">
        <button
          onClick={resetModal}
          className="absolute top-4 right-4 p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 rounded-full hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="flex flex-col items-center text-center">
          <div className="w-16 h-16 bg-blue-100 dark:bg-blue-900/30 rounded-full flex items-center justify-center mb-4">
            <Lock className="w-8 h-8 text-blue-600 dark:text-blue-400" />
          </div>

          <h2 className="mb-2 dark:text-white">
            {mode === 'set'
              ? step === 'enter'
                ? 'Set PIN Lock'
                : 'Confirm PIN'
              : 'Enter PIN'}
          </h2>
          <p className="text-sm text-gray-600 dark:text-gray-400 mb-6">
            {mode === 'set'
              ? step === 'enter'
                ? 'Create a 6-digit PIN to lock this note'
                : 'Re-enter your PIN to confirm'
              : 'Enter your PIN to unlock this note'}
          </p>

          <input
            type="password"
            inputMode="numeric"
            placeholder="Enter PIN"
            value={step === 'confirm' ? confirmPin : pin}
            onChange={(e) => handlePinInput(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleSubmit()}
            disabled={isLocked}
            maxLength={10}
            className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-center tracking-widest text-xl bg-white dark:bg-gray-700 text-gray-900 dark:text-white disabled:opacity-50 disabled:cursor-not-allowed mb-4"
          />

          {error && (
            <div className="flex items-center gap-2 text-red-600 dark:text-red-400 text-sm mb-4">
              <AlertCircle className="w-4 h-4" />
              <span>{error}</span>
            </div>
          )}

          {mode === 'verify' && attempts > 0 && !isLocked && (
            <p className="text-sm text-orange-600 dark:text-orange-400 mb-4">
              {5 - attempts} attempts remaining
            </p>
          )}

          {isLocked && (
            <div className="text-center mb-4">
              <p className="text-sm text-red-600 dark:text-red-400">
                Too many failed attempts
              </p>
              <p className="text-lg font-mono text-red-600 dark:text-red-400">
                {getRemainingCooldown()}s
              </p>
            </div>
          )}

          <div className="flex gap-3 w-full">
            <button
              onClick={resetModal}
              className="flex-1 px-4 py-2.5 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              disabled={isLocked || (step === 'enter' ? pin.length < 6 : confirmPin.length < 6)}
              className="flex-1 px-4 py-2.5 bg-blue-600 hover:bg-blue-700 dark:bg-blue-700 dark:hover:bg-blue-800 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {mode === 'set' ? (step === 'enter' ? 'Next' : 'Set Lock') : 'Unlock'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
