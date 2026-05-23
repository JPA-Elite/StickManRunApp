import { useState, useEffect, useRef } from 'react';
import { Camera, User } from 'lucide-react';
import { toast } from 'sonner';

interface ProfileSectionProps {
  showName?: boolean;
  size?: 'small' | 'medium' | 'large';
  editable?: boolean;
}

export function ProfileSection({ showName = false, size = 'medium', editable = false }: ProfileSectionProps) {
  const [profilePic, setProfilePic] = useState<string | null>(null);
  const [userName, setUserName] = useState<string>('');
  const [isEditingName, setIsEditingName] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const storedPic = localStorage.getItem('profilePic');
    const storedName = localStorage.getItem('userName') || 'User';
    setProfilePic(storedPic);
    setUserName(storedName);
  }, []);

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      toast.error('Please select an image file');
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      toast.error('Image must be smaller than 5MB');
      return;
    }

    const reader = new FileReader();
    reader.onloadend = () => {
      const base64String = reader.result as string;
      setProfilePic(base64String);
      localStorage.setItem('profilePic', base64String);
      toast.success('Profile picture updated!');
    };
    reader.readAsDataURL(file);
  };

  const handleNameSave = () => {
    if (userName.trim()) {
      localStorage.setItem('userName', userName.trim());
      setIsEditingName(false);
      toast.success('Name updated!');
    }
  };

  const sizeClasses = {
    small: 'w-10 h-10',
    medium: 'w-20 h-20',
    large: 'w-32 h-32',
  };

  const iconSizes = {
    small: 'w-5 h-5',
    medium: 'w-10 h-10',
    large: 'w-16 h-16',
  };

  const cameraSizes = {
    small: 'w-4 h-4',
    medium: 'w-5 h-5',
    large: 'w-6 h-6',
  };

  return (
    <div className="flex flex-col items-center gap-3">
      <div className="relative">
        <div className={`${sizeClasses[size]} rounded-full overflow-hidden bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center shadow-lg`}>
          {profilePic ? (
            <img src={profilePic} alt="Profile" className="w-full h-full object-cover" />
          ) : (
            <User className={`${iconSizes[size]} text-white`} />
          )}
        </div>
        {editable && (
          <>
            <button
              onClick={() => fileInputRef.current?.click()}
              className="absolute bottom-0 right-0 bg-blue-600 text-white rounded-full p-2 shadow-lg hover:bg-blue-700 transition-colors"
            >
              <Camera className={cameraSizes[size]} />
            </button>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              onChange={handleImageUpload}
              className="hidden"
            />
          </>
        )}
      </div>

      {showName && (
        <div className="text-center">
          {isEditingName && editable ? (
            <div className="flex items-center gap-2">
              <input
                type="text"
                value={userName}
                onChange={(e) => setUserName(e.target.value)}
                onBlur={handleNameSave}
                onKeyPress={(e) => e.key === 'Enter' && handleNameSave()}
                className="px-3 py-1 border-2 border-white/50 rounded-lg focus:outline-none focus:ring-2 focus:ring-white text-center bg-white/10 text-white placeholder-white/60"
                autoFocus
              />
            </div>
          ) : (
            <button
              onClick={() => editable && setIsEditingName(true)}
              className={`px-4 py-1.5 rounded-lg transition-colors ${
                editable
                  ? 'hover:bg-white/20 cursor-pointer'
                  : ''
              }`}
              disabled={!editable}
            >
              <p className="text-white">{userName}</p>
              {editable && (
                <p className="text-xs text-white/70 mt-0.5">Tap to edit</p>
              )}
            </button>
          )}
        </div>
      )}
    </div>
  );
}
