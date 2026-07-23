import React from 'react';
import { Link } from 'react-router-dom';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ChevronDown, LayoutDashboard, Users, User, LogOut } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { getInitials } from '@/lib/utils';

export const UserMenu: React.FC = () => {
  const { user, logout } = useAuth();

  if (!user) return null;

  const initials = getInitials(user.name, user.email);

  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="flex items-center gap-2 rounded-full outline-none transition hover:opacity-90 focus-visible:ring-2 focus-visible:ring-gray-300">
        <span
          aria-hidden="true"
          className="flex h-9 w-9 items-center justify-center rounded-full bg-black text-sm font-semibold text-white"
        >
          {initials}
        </span>
        <ChevronDown className="h-4 w-4 text-gray-600" />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56">
        <DropdownMenuLabel className="flex flex-col gap-0.5">
          <span className="truncate font-semibold text-gray-900">
            {user.name || 'Your account'}
          </span>
          {user.email && (
            <span className="truncate text-xs font-normal text-gray-500">{user.email}</span>
          )}
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild className="cursor-pointer">
          <Link to="/dashboard">
            <LayoutDashboard className="h-4 w-4" />
            Dashboard
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild className="cursor-pointer">
          <Link to="/contacts">
            <Users className="h-4 w-4" />
            Contacts
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild className="cursor-pointer">
          <Link to="/profile">
            <User className="h-4 w-4" />
            Profile
          </Link>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem variant="destructive" onSelect={logout} className="cursor-pointer">
          <LogOut className="h-4 w-4" />
          Sign Out
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};
