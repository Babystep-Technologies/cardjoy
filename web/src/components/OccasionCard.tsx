import React from 'react';
import { Link } from 'react-router-dom';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent } from '@/components/ui/card';
import { OccasionMenuItem } from '@/config/occasions';
import { ExternalLink } from 'lucide-react';

interface OccasionCardProps {
  occasion: OccasionMenuItem;
}

export const OccasionCard: React.FC<OccasionCardProps> = ({ occasion }) => {
  const destination = occasion.hasLandingPage
    ? `/for/${occasion.slug}`
    : `/card/new?occasion=${encodeURIComponent(occasion.name)}`;

  const isInternal = occasion.hasLandingPage;

  const CardWrapper = ({ children }: { children: React.ReactNode }) => {
    if (isInternal) {
      return (
        <Link to={destination} className="block group">
          {children}
        </Link>
      );
    }
    return (
      <a href={destination} className="block group">
        {children}
      </a>
    );
  };

  return (
    <CardWrapper>
      <Card className="overflow-hidden h-full border-2 hover:border-purple-300 transition-all duration-300 hover:scale-105 hover:shadow-xl">
        <div className="relative aspect-video overflow-hidden">
          <img
            src={occasion.imageUrl}
            alt={occasion.name}
            className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"
            loading="lazy"
          />
          <div className={`absolute inset-0 bg-gradient-to-br ${occasion.color} opacity-20`}></div>
        </div>
        <CardContent className="p-6">
          <div className="flex items-start justify-between gap-2 mb-2">
            <h3 className="text-xl font-bold text-gray-900">{occasion.name}</h3>
            {occasion.hasLandingPage && (
              <Badge variant="secondary" className="shrink-0 bg-purple-100 text-purple-700">
                Featured
              </Badge>
            )}
          </div>
          <p className="text-gray-600 text-sm mb-4">{occasion.description}</p>
          <div className="flex items-center gap-2 text-purple-600 font-semibold text-sm group-hover:gap-3 transition-all">
            {occasion.hasLandingPage ? 'Learn More' : 'Create Card'}
            {!isInternal && <ExternalLink className="w-4 h-4" />}
          </div>
        </CardContent>
      </Card>
    </CardWrapper>
  );
};
