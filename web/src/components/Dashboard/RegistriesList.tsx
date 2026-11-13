import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { format, parseISO } from 'date-fns';
import { Gift, Pencil, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { occasionLabel } from '@/lib/wishList';

export interface DashboardRegistry {
  externalId: string;
  title: string;
  occasion?: string | null;
  eventDate?: string | null;
  standalone: boolean;
  items: { id: string }[];
}

interface RegistriesListProps {
  registries: DashboardRegistry[];
  onDelete: (externalId: string) => void;
}

/** The dashboard's registries tab (#245): one card per registry, with edit and delete. */
export const RegistriesList: React.FC<RegistriesListProps> = ({ registries, onDelete }) => {
  const navigate = useNavigate();

  if (registries.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 py-12 text-center">
        <Gift className="h-10 w-10 text-yellow-500" />
        <h3 className="text-xl font-semibold text-gray-800">
          You haven&apos;t made a registry yet
        </h3>
        <p className="max-w-md text-gray-500">
          List what you&apos;d love for a birthday, wedding, or any occasion, and let friends and
          family pick something.
        </p>
        <Button onClick={() => navigate('/registry/new')}>Create a Registry</Button>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button asChild>
          <Link to="/registry/new">Create a Registry</Link>
        </Button>
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {registries.map(registry => {
          const occasion = occasionLabel(registry.occasion);
          return (
            <Card key={registry.externalId}>
              <CardContent className="flex h-full flex-col gap-3 p-5">
                <div>
                  <h3 className="line-clamp-2 text-lg font-semibold text-gray-900">
                    {registry.title}
                  </h3>
                  <p className="text-sm text-gray-500">
                    {[
                      occasion,
                      registry.eventDate
                        ? format(parseISO(registry.eventDate), 'MMM d, yyyy')
                        : null,
                      registry.standalone ? null : 'Invitation wish list',
                    ]
                      .filter(Boolean)
                      .join(' · ') || 'Registry'}
                  </p>
                </div>
                <p className="text-sm text-gray-600">
                  {registry.items.length} {registry.items.length === 1 ? 'item' : 'items'}
                </p>
                <div className="mt-auto flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => navigate(`/registry/${registry.externalId}/edit`)}
                  >
                    <Pencil className="mr-1 h-4 w-4" /> Edit
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-red-600"
                    onClick={() => onDelete(registry.externalId)}
                  >
                    <Trash2 className="mr-1 h-4 w-4" /> Delete
                  </Button>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
};
