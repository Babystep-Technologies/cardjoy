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
import { Building2, Check, ChevronDown, Coins, Plus, Settings, Users } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { useOrganization } from '@/contexts/OrganizationContext';

/**
 * The active-context switcher: Personal plus every organization the user belongs to.
 *
 * Renders nothing until the user actually belongs to an organization — a switcher with one entry is
 * clutter. Until then, `UserMenu` carries the "Create organization" entry instead.
 */
export const OrganizationMenu: React.FC = () => {
  const { user } = useAuth();
  const { activeOrganization, organizations, switchOrganization, switching, switchError } =
    useOrganization();

  if (!user || organizations.length === 0) return null;

  return (
    <DropdownMenu>
      {/* A bordered chip rather than a plain nav link: the marketing nav already has a "Personal"
          entry, and the two must not read as the same control. */}
      <DropdownMenuTrigger className="flex max-w-[200px] items-center gap-1.5 rounded-full border border-gray-200 bg-gray-50 px-3 py-1.5 text-sm font-medium text-gray-700 outline-none transition hover:border-gray-300 hover:text-gray-900">
        <Building2 className="h-4 w-4 shrink-0" />
        <span className="truncate">{activeOrganization?.name ?? 'Personal'}</span>
        <ChevronDown className="h-4 w-4 shrink-0" />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-64">
        <DropdownMenuLabel className="text-xs font-normal uppercase tracking-wide text-gray-500">
          Switch context
        </DropdownMenuLabel>
        {switchError && (
          <DropdownMenuLabel className="text-xs font-normal text-red-600">
            {switchError}
          </DropdownMenuLabel>
        )}
        <DropdownMenuItem
          disabled={switching}
          onSelect={() => switchOrganization(null)}
          className="cursor-pointer"
        >
          <Check
            className={`h-4 w-4 ${activeOrganization ? 'opacity-0' : 'text-gray-900'}`}
            aria-hidden={!!activeOrganization}
          />
          <span className="truncate">Personal</span>
        </DropdownMenuItem>
        {organizations.map(organization => {
          const isActive = organization.id === activeOrganization?.id;

          return (
            <DropdownMenuItem
              key={organization.id}
              disabled={switching}
              onSelect={() => switchOrganization(organization.id)}
              className="cursor-pointer"
            >
              <Check
                className={`h-4 w-4 ${isActive ? 'text-gray-900' : 'opacity-0'}`}
                aria-hidden={!isActive}
              />
              <span className="truncate">{organization.name}</span>
              <span className="ml-auto text-xs text-gray-500">{organization.role}</span>
            </DropdownMenuItem>
          );
        })}
        <DropdownMenuSeparator />
        {activeOrganization && (
          <>
            <DropdownMenuItem asChild className="cursor-pointer">
              <Link to="/organizations/members">
                <Users className="h-4 w-4" />
                Members
              </Link>
            </DropdownMenuItem>
            <DropdownMenuItem asChild className="cursor-pointer">
              <Link to="/organizations/credits">
                <Coins className="h-4 w-4" />
                Credits
              </Link>
            </DropdownMenuItem>
            <DropdownMenuItem asChild className="cursor-pointer">
              <Link to="/organizations/settings">
                <Settings className="h-4 w-4" />
                Organization settings
              </Link>
            </DropdownMenuItem>
          </>
        )}
        <DropdownMenuItem asChild className="cursor-pointer">
          <Link to="/organizations/new">
            <Plus className="h-4 w-4" />
            Create organization
          </Link>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};

/**
 * The same switcher for the mobile menu, where the header renders a flat list rather than dropdowns.
 * A user with no organizations gets only the "Create organization" link.
 */
export const MobileOrganizationSwitcher: React.FC<{ onNavigate: () => void }> = ({
  onNavigate,
}) => {
  const { user } = useAuth();
  const { activeOrganization, organizations, switchOrganization, switching, switchError } =
    useOrganization();

  if (!user) return null;

  const entryClass =
    'flex w-full items-center gap-2 rounded-md px-2 py-2 text-left text-gray-700 transition hover:bg-gray-50 disabled:opacity-50';

  return (
    <>
      {organizations.length > 0 && (
        <div className="flex flex-col gap-1">
          <p className="px-2 text-xs font-semibold uppercase tracking-wide text-gray-500">
            Switch context
          </p>
          {switchError && <p className="px-2 text-xs text-red-600">{switchError}</p>}
          {[null, ...organizations].map(organization => {
            const isActive = (organization?.id ?? null) === (activeOrganization?.id ?? null);

            return (
              <button
                key={organization?.id ?? 'personal'}
                type="button"
                disabled={switching}
                onClick={() => switchOrganization(organization?.id ?? null)}
                className={entryClass}
              >
                <Check
                  className={`h-4 w-4 ${isActive ? 'text-gray-900' : 'opacity-0'}`}
                  aria-hidden={!isActive}
                />
                <span className="truncate">{organization?.name ?? 'Personal'}</span>
                {organization && (
                  <span className="ml-auto text-xs text-gray-500">{organization.role}</span>
                )}
              </button>
            );
          })}
        </div>
      )}
      {activeOrganization && (
        <>
          <Link to="/organizations/members" onClick={onNavigate} className={entryClass}>
            <Users className="h-4 w-4" />
            Members
          </Link>
          <Link to="/organizations/credits" onClick={onNavigate} className={entryClass}>
            <Coins className="h-4 w-4" />
            Credits
          </Link>
          <Link to="/organizations/settings" onClick={onNavigate} className={entryClass}>
            <Settings className="h-4 w-4" />
            Organization settings
          </Link>
        </>
      )}
      <Link to="/organizations/new" onClick={onNavigate} className={entryClass}>
        <Plus className="h-4 w-4" />
        Create organization
      </Link>
    </>
  );
};
