import { Link, useLocation } from 'react-router-dom';
import { useState } from 'react';
import {
  ImageIcon,
  UsersIcon,
  CreditCardIcon,
  Menu,
  LogOut,
  CoinsIcon,
  HomeIcon,
  MailIcon,
} from 'lucide-react';
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/contexts/AuthContext';

const navLinks = [
  { href: '/', label: 'Home', icon: HomeIcon },
  { href: '/styles', label: 'Styles', icon: ImageIcon },
  { href: '/cards', label: 'Cards', icon: CreditCardIcon },
  { href: '/invitations', label: 'Invitations', icon: MailIcon },
  { href: '/users', label: 'Users', icon: UsersIcon },
  { href: '/credits', label: 'Credits & Promos', icon: CoinsIcon },
];

export default function Sidebar() {
  const location = useLocation();
  const [open, setOpen] = useState(false);
  const { logout } = useAuth();

  const LogoHeader = () => (
    <Link
      to="/"
      className="flex flex-col items-start gap-1 px-3 py-4 rounded-md bg-gradient-to-r from-white to-gray-50"
      onClick={() => setOpen(false)}
    >
      <img src="/font-logo.svg" alt="CardJoy" className="w-24 h-auto" />
      <span className="text-black font-semibold text-sm tracking-tight pl-[2px]">Admin</span>
    </Link>
  );

  const NavContent = () => (
    <nav className="space-y-2 mt-6">
      {navLinks.map(({ href, label, icon: Icon }) => {
        const isActive = location.pathname === href;
        return (
          <Link
            key={href}
            to={href}
            onClick={() => setOpen(false)}
            className={`flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors ${
              isActive ? 'bg-black text-white' : 'text-black hover:bg-gray-100'
            }`}
          >
            <Icon className="w-4 h-4 mr-2" />
            {label}
          </Link>
        );
      })}

      <Link
        onClick={() => logout()}
        to="/"
        className="flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors text-black hover:bg-gray-100"
      >
        <LogOut className="w-4 h-4 mr-2" />
        Log out
      </Link>
    </nav>
  );

  return (
    <>
      {/* Desktop Sidebar */}
      <aside className="hidden md:flex md:flex-col w-64 border-r bg-white px-4 py-6">
        <LogoHeader />
        <NavContent />
      </aside>

      {/* Mobile Sidebar */}
      <Sheet open={open} onOpenChange={setOpen}>
        <SheetTrigger asChild>
          <Button className="md:hidden fixed top-4 left-4 z-50 p-2 rounded-md bg-white text-black">
            <Menu className="h-5 w-5 text-black" />
          </Button>
        </SheetTrigger>
        <SheetContent side="left" className="w-[250px] bg-white p-4">
          <LogoHeader />
          <NavContent />
        </SheetContent>
      </Sheet>
    </>
  );
}
