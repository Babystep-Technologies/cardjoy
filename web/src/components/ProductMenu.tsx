import React from 'react';
import { Link } from 'react-router-dom';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ChevronDown, Mail, PartyPopper } from 'lucide-react';

const products = [
  {
    name: 'Group Cards',
    to: '/card/new',
    description: 'Collect heartfelt messages, photos & wishes from everyone.',
    icon: Mail,
    gradient: 'from-[var(--color-brand-pink)] to-[var(--color-brand-blue)]',
  },
  {
    name: 'Invitations',
    to: '/invitation/new',
    description: 'Beautiful animated invites with built-in RSVP.',
    icon: PartyPopper,
    gradient: 'from-[var(--color-brand-blue)] to-[var(--color-brand-green)]',
  },
];

export const ProductMenu: React.FC = () => {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="flex items-center gap-1 text-gray-600 hover:text-gray-900 transition font-medium text-base outline-none">
        Products
        <ChevronDown className="w-4 h-4" />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-[360px] p-3" align="start">
        <div className="flex flex-col gap-1">
          {products.map(product => (
            <DropdownMenuItem key={product.to} asChild className="p-0 focus:bg-transparent">
              <Link
                to={product.to}
                className="flex items-start gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors cursor-pointer"
              >
                <div
                  className={`shrink-0 flex items-center justify-center w-10 h-10 rounded-lg bg-gradient-to-br ${product.gradient}`}
                >
                  <product.icon className="w-5 h-5 text-white" />
                </div>
                <div>
                  <div className="font-semibold text-gray-900 text-sm">{product.name}</div>
                  <div className="text-xs text-gray-500 mt-0.5 leading-snug">
                    {product.description}
                  </div>
                </div>
              </Link>
            </DropdownMenuItem>
          ))}
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};
