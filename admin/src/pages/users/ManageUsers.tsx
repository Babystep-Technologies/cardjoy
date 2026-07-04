import { useState, useEffect } from 'react';
import { useQuery, gql } from '@apollo/client';
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

interface User {
  id: string;
  email: string;
  name: string;
  creditBalance: number;
  cardsCount: number;
  invitationsCount: number;
  createdAt: string;
}

const ADMIN_USERS_QUERY = gql`
  query AdminUsers($page: Int, $perPage: Int, $search: String) {
    adminUsers(page: $page, perPage: $perPage, search: $search) {
      users {
        id
        email
        name
        creditBalance
        cardsCount
        invitationsCount
        createdAt
      }
      totalCount
      page
      perPage
      totalPages
    }
  }
`;

function ManageUsers() {
  const [searchInput, setSearchInput] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const perPage = 20;

  const { data, loading, error } = useQuery(ADMIN_USERS_QUERY, {
    variables: {
      page: currentPage,
      perPage,
      search: searchTerm || null,
    },
  });

  // Reset to page 1 when search changes
  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm]);

  const handleSearch = () => {
    setSearchTerm(searchInput.trim());
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch();
    }
  };

  const handleClear = () => {
    setSearchInput('');
    setSearchTerm('');
  };

  const users = data?.adminUsers.users || [];
  const totalCount = data?.adminUsers.totalCount || 0;
  const totalPages = data?.adminUsers.totalPages || 0;

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  return (
    <div className="flex flex-col space-y-6">
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4">
        <h2 className="text-2xl font-bold text-black">Manage Users</h2>
        <div className="text-sm text-gray-600">
          Total Users: <span className="font-semibold">{totalCount}</span>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
          <Input
            placeholder="Search by name or email..."
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
        ) : users.length === 0 ? (
          <div className="flex justify-center items-center h-48">
            <p className="text-gray-500 text-lg">
              {searchTerm ? 'No users found matching your search' : 'No users found'}
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
                    <TableHead>Email</TableHead>
                    <TableHead className="text-center">Credits</TableHead>
                    <TableHead className="text-center">Cards</TableHead>
                    <TableHead className="text-center">Invitations</TableHead>
                    <TableHead>Joined</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {users.map((user: User) => (
                    <TableRow key={user.id}>
                      <TableCell className="font-medium">{user.name}</TableCell>
                      <TableCell className="text-gray-600">{user.email}</TableCell>
                      <TableCell className="text-center">{user.creditBalance}</TableCell>
                      <TableCell className="text-center">{user.cardsCount}</TableCell>
                      <TableCell className="text-center">{user.invitationsCount}</TableCell>
                      <TableCell className="text-gray-600 text-sm">
                        {formatDate(user.createdAt)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            {/* Mobile Card View */}
            <div className="md:hidden divide-y">
              {users.map((user: User) => (
                <div key={user.id} className="p-4 space-y-2">
                  <div className="font-medium text-lg">{user.name}</div>
                  <div className="text-sm text-gray-600">{user.email}</div>
                  <div className="grid grid-cols-3 gap-2 pt-2 text-sm">
                    <div>
                      <div className="text-gray-500">Credits</div>
                      <div className="font-medium">{user.creditBalance}</div>
                    </div>
                    <div>
                      <div className="text-gray-500">Cards</div>
                      <div className="font-medium">{user.cardsCount}</div>
                    </div>
                    <div>
                      <div className="text-gray-500">Invitations</div>
                      <div className="font-medium">{user.invitationsCount}</div>
                    </div>
                  </div>
                  <div className="text-xs text-gray-500 pt-1">
                    Joined {formatDate(user.createdAt)}
                  </div>
                </div>
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

export default withAuth(ManageUsers);
