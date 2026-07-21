import React from 'react';
import { Link } from 'react-router-dom';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ChevronDown } from 'lucide-react';
import { cardTypes } from '@/config/cardTypes';

export const ProductMenu: React.FC = () => {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="flex items-center gap-1 text-gray-600 hover:text-gray-900 transition font-medium text-base outline-none">
        Personal
        <ChevronDown className="w-4 h-4" />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-[360px] p-3" align="start">
        <div className="flex flex-col gap-1">
          {cardTypes.map(product => {
            const iconTile = (
              <div
                className={`shrink-0 flex items-center justify-center w-10 h-10 rounded-lg bg-gradient-to-br ${product.gradient}`}
              >
                <product.icon className="w-5 h-5 text-white" />
              </div>
            );
            const body = (
              <div>
                <div className="font-semibold text-gray-900 text-sm flex items-center gap-2">
                  {product.label}
                  {product.comingSoon && (
                    <span className="text-[10px] font-semibold uppercase tracking-wide text-gray-400 border border-gray-200 rounded-full px-1.5 py-0.5">
                      Soon
                    </span>
                  )}
                </div>
                <div className="text-xs text-gray-500 mt-0.5 leading-snug">
                  {product.description}
                </div>
              </div>
            );

            if (product.comingSoon) {
              return (
                <DropdownMenuItem
                  key={product.id}
                  disabled
                  className="p-0 focus:bg-transparent opacity-60"
                >
                  <div className="flex items-start gap-3 p-3 rounded-lg">
                    {iconTile}
                    {body}
                  </div>
                </DropdownMenuItem>
              );
            }

            return (
              <DropdownMenuItem key={product.id} asChild className="p-0 focus:bg-transparent">
                <Link
                  to={product.route}
                  className="flex items-start gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors cursor-pointer"
                >
                  {iconTile}
                  {body}
                </Link>
              </DropdownMenuItem>
            );
          })}
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};
