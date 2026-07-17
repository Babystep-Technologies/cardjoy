import React from 'react';
import { Link } from 'react-router-dom';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { occasions } from '@/config/occasions';
import { ChevronDown } from 'lucide-react';

export const OccasionMegaMenu: React.FC = () => {
  const featuredOccasions = occasions.filter(o => o.featured).slice(0, 6);

  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="flex items-center gap-1 text-gray-600 hover:text-gray-900 transition font-medium text-base outline-none">
        Occasions
        <ChevronDown className="w-4 h-4" />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-[600px] p-6" align="start">
        <div className="grid grid-cols-3 gap-4 mb-4">
          {featuredOccasions.map(occasion => {
            const destination = occasion.hasLandingPage
              ? `/for/${occasion.slug}`
              : `/group-card/new?occasion=${encodeURIComponent(occasion.name)}`;

            return (
              <DropdownMenuItem key={occasion.slug} asChild className="p-0 focus:bg-transparent">
                <Link
                  to={destination}
                  className="flex flex-col items-center gap-2 p-3 rounded-lg hover:bg-gray-50 transition-colors group cursor-pointer"
                >
                  <div className="relative w-[150px] h-[150px] rounded-lg overflow-hidden">
                    <img
                      src={occasion.imageUrl}
                      alt={occasion.name}
                      className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"
                    />
                    <div
                      className={`absolute inset-0 bg-gradient-to-br ${occasion.color} opacity-20`}
                    ></div>
                  </div>
                  <div className="text-center">
                    <div className="font-semibold text-gray-900 text-sm">{occasion.name}</div>
                    <div className="text-xs text-gray-500 mt-1 line-clamp-2">
                      {occasion.description}
                    </div>
                  </div>
                </Link>
              </DropdownMenuItem>
            );
          })}
        </div>
        <div className="pt-4 border-t border-gray-200">
          <Link
            to="/occasions"
            className="text-purple-600 hover:text-purple-700 font-semibold text-sm flex items-center justify-center gap-1 hover:gap-2 transition-all"
          >
            Browse All Occasions →
          </Link>
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};
