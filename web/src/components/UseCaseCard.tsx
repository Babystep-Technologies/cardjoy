import React from 'react';
import { Link } from 'react-router-dom';
import { LucideIcon } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

interface UseCaseCardProps {
  story: string; // Mini narrative
  occasion: string; // Display name
  link: string; // Landing page URL or card creation URL
  icon: LucideIcon;
  gradient: string; // Tailwind classes
}

export const UseCaseCard: React.FC<UseCaseCardProps> = ({
  story,
  occasion,
  link,
  icon: Icon,
  gradient,
}) => {
  const isExternal = link.startsWith('http') || link.includes('?');

  const CardWrapper = ({ children }: { children: React.ReactNode }) => {
    if (isExternal && !link.startsWith('/')) {
      return (
        <a href={link} className="block group h-full">
          {children}
        </a>
      );
    }
    return (
      <Link to={link} className="block group h-full">
        {children}
      </Link>
    );
  };

  return (
    <CardWrapper>
      <Card
        className={`h-full overflow-hidden bg-gradient-to-br ${gradient} border-0 hover:scale-105 transition-all duration-300 hover:shadow-2xl`}
      >
        <CardContent className="p-8 flex flex-col h-full justify-between">
          <div>
            <div className="mb-4">
              <Icon className="w-12 h-12 text-white drop-shadow-lg" />
            </div>
            <h3 className="text-2xl font-bold text-white mb-3 drop-shadow-md">{occasion}</h3>
            <p className="text-white/90 text-base leading-relaxed drop-shadow-sm">{story}</p>
          </div>
          <div className="mt-6 text-white font-semibold flex items-center gap-2 group-hover:gap-3 transition-all">
            <span>Explore →</span>
          </div>
        </CardContent>
      </Card>
    </CardWrapper>
  );
};
