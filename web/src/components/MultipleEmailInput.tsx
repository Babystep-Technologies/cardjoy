import { useState } from 'react';
import { Input } from '@/components/ui/input';
import { X } from 'lucide-react';

interface MultiEmailInputProps {
  value: string[];
  onChange: (emails: string[]) => void;
  placeholder?: string;
}

const MultiEmailInput: React.FC<MultiEmailInputProps> = ({
  value,
  onChange,
  placeholder = 'Enter email(s)',
}) => {
  const [inputValue, setInputValue] = useState('');

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if ((e.key === 'Enter' || e.key === ',' || e.key === 'Tab') && inputValue.trim()) {
      e.preventDefault();
      const email = inputValue.trim().replace(/,$/, '');
      if (validateEmail(email) && !value.includes(email)) {
        onChange([...value, email]);
      }
      setInputValue('');
    }
  };

  const handleRemove = (emailToRemove: string) => {
    onChange(value.filter(email => email !== emailToRemove));
  };

  const validateEmail = (email: string) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  return (
    <div className="mb-4">
      <div className="flex flex-wrap gap-2 mb-2">
        {value.map(email => (
          <span
            key={email}
            className="flex items-center gap-1 bg-gray-200 text-black px-3 py-1 rounded-full text-sm"
          >
            {email}
            <button
              type="button"
              onClick={() => handleRemove(email)}
              className="text-gray-600 hover:text-red-500"
            >
              <X className="w-4 h-4" />
            </button>
          </span>
        ))}
      </div>
      <Input
        type="email"
        placeholder={placeholder}
        value={inputValue}
        onChange={e => setInputValue(e.target.value)}
        onKeyDown={handleKeyDown}
        className="bg-white text-black"
      />
    </div>
  );
};

export default MultiEmailInput;
