import { useState, useEffect } from 'react';
import { useQuery, gql } from '@apollo/client';
import { Link } from 'react-router-dom';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Skeleton } from '@/components/ui/skeleton';
import { Search, ChevronLeft, ChevronRight } from 'lucide-react';
import withAuth from '@/lib/with-auth';
import { Organization } from '@/types/app';

const ADMIN_ORGANIZATIONS_QUERY = gql`
  query AdminOrganizations($page: Int, $perPage: Int, $search: String) {
    adminOrganizations(page: $page, perPage: $perPage, search: $search) {
      organizations {
        id
        name
        slug
        description
        membersCount
        creditBalance
        createdAt
      }
      totalCount
      page
      perPage
      totalPages
    }
  }
`;

const formatDate = (dateString: string) =>
  new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });

function ManageOrganizations() {
  const [searchInput, setSearchInput] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const perPage = 20;

  const { data, loading, error } = useQuery(ADMIN_ORGANIZATIONS_QUERY, {
    variables: { page: currentPage, perPage, search: searchTerm || null },
  });

  // Reset to page 1 when search changes
  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm]);

  const handleSearch = () => setSearchTerm(searchInput.trim());

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleSearch();
  };

  const handleClear = () => {
    setSearchInput('');
    setSearchTerm('');
  };

  const organizations: Organization[] = data?.adminOrganizations.organizations || [];
  const totalCount = data?.adminOrganizations.totalCount || 0;
  const totalPages = data?.adminOrganizations.totalPages || 0;

  return (
    <div className="flex flex-col space-y-6">
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4">
        <h2 className="text-2xl font-bold text-black">Organizations</h2>
        <div className="text-sm text-gray-600">
          Total Organizations: <span className="font-semibold">{totalCount}</span>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
          <Input
            placeholder="Search by name or slug..."
            value={searchInput}
            onChange={e => setSearchInput(e.target.value)}
            onKeyPress={handleKeyPress}
            className="pl-10 bg-white"
          />
        </div>
        <div className="flex gap-2">
          <Button onClick={handleSearch} disabled={loading} className="flex-1 sm:flex-none">
            Search
          </Button>
          {searchTerm && (
            <Button variant="outline" onClick={handleClear} className="flex-1 sm:flex-none">
              Clear
            </Button>
          )}
        </div>
      </div>

      {error && (
        <div className="text-red-500 text-sm bg-red-50 p-3 rounded-md">Error: {error.message}</div>
      )}

      <Card>
        {loading ? (
          <div className="p-6 space-y-3">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        ) : organizations.length === 0 ? (
          <div className="flex justify-center items-center h-48">
            <p className="text-gray-500 text-lg">
              {searchTerm
                ? 'No organizations found matching your search'
                : 'No organizations found'}
            </p>
          </div>
        ) : (
          <>
            {/* Desktop Table View */}
            <div className="hidden md:block overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Slug</TableHead>
                    <TableHead className="text-center">Members</TableHead>
                    <TableHead className="text-center">Pool credits</TableHead>
                    <TableHead>Created</TableHead>
                    <TableHead />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {organizations.map(organization => (
                    <TableRow key={organization.id}>
                      <TableCell className="font-medium">
                        <Link
                          to={`/organizations/${organization.id}`}
                          className="hover:underline text-black"
                        >
                          {organization.name}
                        </Link>
                      </TableCell>
                      <TableCell className="text-gray-600 font-mono text-sm">
                        {organization.slug}
                      </TableCell>
                      <TableCell className="text-center">{organization.membersCount}</TableCell>
                      <TableCell className="text-center">{organization.creditBalance}</TableCell>
                      <TableCell className="text-gray-600 text-sm">
                        {formatDate(organization.createdAt)}
                      </TableCell>
                      <TableCell className="text-right">
                        <Link
                          to={`/organizations/${organization.id}`}
                          className="text-sm text-gray-500 hover:text-black inline-flex items-center"
                        >
                          View
                          <ChevronRight className="h-4 w-4 ml-1" />
                        </Link>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            {/* Mobile Card View */}
            <div className="md:hidden divide-y">
              {organizations.map(organization => (
                <Link
                  key={organization.id}
                  to={`/organizations/${organization.id}`}
                  className="block p-4 space-y-2"
                >
                  <div className="font-medium text-lg text-black">{organization.name}</div>
                  <div className="text-sm text-gray-600 font-mono">{organization.slug}</div>
                  <div className="grid grid-cols-2 gap-2 pt-2 text-sm">
                    <div>
                      <div className="text-gray-500">Members</div>
                      <div className="font-medium">{organization.membersCount}</div>
                    </div>
                    <div>
                      <div className="text-gray-500">Pool credits</div>
                      <div className="font-medium">{organization.creditBalance}</div>
                    </div>
                  </div>
                  <div className="text-xs text-gray-500 pt-1">
                    Created {formatDate(organization.createdAt)}
                  </div>
                </Link>
              ))}
            </div>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-between border-t px-4 py-3">
                <div className="text-sm text-gray-600">
                  Page {currentPage} of {totalPages}
                </div>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                    disabled={currentPage === 1 || loading}
                  >
                    <ChevronLeft className="h-4 w-4" />
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                    disabled={currentPage === totalPages || loading}
                  >
                    Next
                    <ChevronRight className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            )}
          </>
        )}
      </Card>
    </div>
  );
}

export default withAuth(ManageOrganizations);
