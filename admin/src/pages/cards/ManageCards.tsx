import { useQuery, gql, useMutation } from '@apollo/client';
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from '@/components/ui/dropdown-menu';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { MoreVertical, Trash2, Lock, Unlock, Flag, ShieldCheck, FileText } from 'lucide-react';
import { toast, Toaster } from 'sonner';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { Card } from '@/types/app';
import clsx from 'clsx';

const GET_ADMIN_CARDS = gql`
  query GetAdminCards($page: Int!, $perPage: Int!, $search: String) {
    adminCards(page: $page, perPage: $perPage, search: $search) {
      cards {
        id
        externalId
        title
        createdAt
        locked
        flagged
        deleted
      }
      totalCount
      currentPage
      perPage
    }
  }
`;

const UPDATE_CARD_BY_ADMIN = gql`
  mutation UpdateCardByAdmin($input: UpdateCardByAdminInput!) {
    updateCardByAdmin(input: $input) {
      card {
        id
        externalId
        locked
        flagged
        deleted
      }
      errors
    }
  }
`;

const ManageCards: React.FC = () => {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [page, setPage] = useState(1);
  const [pendingAction, setPendingAction] = useState<{ externalId: string; action: string } | null>(
    null
  );

  const { data, loading, error, refetch } = useQuery(GET_ADMIN_CARDS, {
    variables: { page, perPage: 10, search },
  });

  const [updateCard] = useMutation(UPDATE_CARD_BY_ADMIN);

  const confirmAction = async () => {
    if (!pendingAction) return;
    const { externalId, action } = pendingAction;
    const { data } = await updateCard({ variables: { input: { externalId, action } } });
    if (data?.updateCardByAdmin?.errors?.length) {
      toast.error(data.updateCardByAdmin.errors.join(', '));
    } else {
      toast.success(`${action} succeeded`);
      refetch();
    }
    setPendingAction(null);
  };

  const getConfirmationMessage = (action: string) => {
    switch (action) {
      case 'lock':
        return 'Locking this card will prevent new messages from being added. Are you sure?';
      case 'unlock':
        return 'Unlocking this card will allow new messages. Proceed?';
      case 'flag':
        return 'Flagging this card will hide it from users. Continue?';
      case 'unflag':
        return 'Unflagging will make this card visible to users again. Proceed?';
      case 'archive':
        return 'Archiving this card will delete the card. Are you sure?';
      default:
        return 'Are you sure you want to proceed with this action?';
    }
  };

  const cards = data?.adminCards.cards || [];
  const totalPages = Math.ceil((data?.adminCards.totalCount || 0) / 10);

  const handleViewCard = (cardExternalId: string) => {
    const cardIds = cards.map((card: Card) => card.externalId);
    const currentIndex = cardIds.indexOf(cardExternalId);
    navigate(`/card/${cardExternalId}`, {
      state: { cardIds, currentIndex },
    });
  };

  useEffect(() => {
    refetch();
  }, [page, search, refetch]);

  if (loading) return <LoadingScreen />;
  if (error) return <ErrorScreen details={error.message} />;

  return (
    <div className="flex flex-col min-h-[calc(100vh-80px)] space-y-6">
      <Toaster />

      <Dialog open={!!pendingAction} onOpenChange={open => !open && setPendingAction(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirm Action</DialogTitle>
            <DialogDescription>
              {pendingAction && getConfirmationMessage(pendingAction.action)}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="secondary" onClick={() => setPendingAction(null)}>
              Cancel
            </Button>
            <Button onClick={confirmAction}>Confirm</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-black">Manage Cards</h2>
      </div>

      <form
        className="flex items-center gap-3 mb-4"
        onSubmit={e => {
          e.preventDefault();
          setSearch(searchInput);
        }}
      >
        <Input
          placeholder="Search by card title..."
          value={searchInput}
          onChange={e => setSearchInput(e.target.value)}
          className="bg-white w-full max-w-md"
        />
        <Button type="submit">Search</Button>
        <Button
          type="button"
          variant="ghost"
          onClick={() => {
            setSearchInput('');
            setSearch('');
          }}
        >
          Reset
        </Button>
      </form>

      {/* Desktop Table View */}
      <div className="hidden md:block flex-1 overflow-auto">
        <Table className="bg-white rounded-xl shadow-sm min-h-[400px] w-full">
          <TableHeader>
            <TableRow>
              <TableHead className="text-center">Title</TableHead>
              <TableHead className="text-center">Created At</TableHead>
              <TableHead className="text-center">Locked</TableHead>
              <TableHead className="text-center">Flagged</TableHead>
              <TableHead className="text-center">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {cards.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5} className="text-center py-6 text-gray-500">
                  No cards found.
                </TableCell>
              </TableRow>
            ) : (
              cards.map((card: Card) => (
                <TableRow key={card.externalId}>
                  <TableCell className="text-center align-top pt-4">{card.title}</TableCell>
                  <TableCell className="text-center align-top pt-4">
                    {new Date(card.createdAt).toLocaleDateString()}
                  </TableCell>
                  <TableCell className="text-center align-top pt-4">
                    <span
                      className={clsx(
                        'px-2 py-1 rounded text-sm font-medium',
                        card.locked ? 'bg-yellow-100 text-yellow-800' : 'text-gray-500'
                      )}
                    >
                      {card.locked ? 'Yes' : 'No'}
                    </span>
                  </TableCell>
                  <TableCell className="text-center align-top pt-4">
                    <span
                      className={clsx(
                        'px-2 py-1 rounded text-sm font-medium',
                        card.flagged ? 'bg-red-100 text-red-700' : 'text-gray-500'
                      )}
                    >
                      {card.flagged ? 'Yes' : 'No'}
                    </span>
                  </TableCell>
                  <TableCell className="text-center align-top">
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button size="icon" variant="ghost">
                          <MoreVertical className="w-5 h-5 text-gray-600" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent sideOffset={4} className="z-50 w-48 text-sm">
                        <DropdownMenuItem
                          onClick={() =>
                            setPendingAction({
                              externalId: card.externalId,
                              action: card.locked ? 'unlock' : 'lock',
                            })
                          }
                        >
                          {card.locked ? (
                            <Unlock className="mr-2 h-4 w-4" />
                          ) : (
                            <Lock className="mr-2 h-4 w-4" />
                          )}
                          {card.locked ? 'Unlock' : 'Lock'}
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          onClick={() =>
                            setPendingAction({
                              externalId: card.externalId,
                              action: card.flagged ? 'unflag' : 'flag',
                            })
                          }
                        >
                          {card.flagged ? (
                            <ShieldCheck className="mr-2 h-4 w-4 text-green-600" />
                          ) : (
                            <Flag className="mr-2 h-4 w-4 text-red-600" />
                          )}
                          {card.flagged ? 'Unflag' : 'Flag'}
                        </DropdownMenuItem>
                        <DropdownMenuItem onClick={() => handleViewCard(card.externalId)}>
                          <FileText className="mr-2 h-4 w-4" />
                          View Card
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          onClick={() =>
                            setPendingAction({
                              externalId: card.externalId,
                              action: card.deleted ? 'unarchive' : 'archive',
                            })
                          }
                          className="text-red-500"
                        >
                          <Trash2 className="mr-2 h-4 w-4" />
                          {card.deleted ? 'Unarchive' : 'Archive'}
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {/* Mobile Card View */}
      <div className="md:hidden divide-y bg-white rounded-xl shadow-sm min-h-[400px]">
        {cards.length === 0 ? (
          <div className="flex justify-center items-center h-48">
            <p className="text-gray-500">No cards found.</p>
          </div>
        ) : (
          cards.map((card: Card) => (
            <div key={card.externalId} className="p-4 space-y-3">
              <div className="flex justify-between items-start gap-2">
                <div className="flex-1">
                  <div className="font-medium text-lg text-black">{card.title}</div>
                  <div className="text-sm text-gray-500">{card.externalId}</div>
                </div>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button size="icon" variant="ghost">
                      <MoreVertical className="w-5 h-5 text-gray-600" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent sideOffset={4} className="z-50 w-48 text-sm">
                    <DropdownMenuItem
                      onClick={() =>
                        setPendingAction({
                          externalId: card.externalId,
                          action: card.locked ? 'unlock' : 'lock',
                        })
                      }
                    >
                      {card.locked ? (
                        <Unlock className="mr-2 h-4 w-4" />
                      ) : (
                        <Lock className="mr-2 h-4 w-4" />
                      )}
                      {card.locked ? 'Unlock' : 'Lock'}
                    </DropdownMenuItem>
                    <DropdownMenuItem
                      onClick={() =>
                        setPendingAction({
                          externalId: card.externalId,
                          action: card.flagged ? 'unflag' : 'flag',
                        })
                      }
                    >
                      {card.flagged ? (
                        <ShieldCheck className="mr-2 h-4 w-4 text-green-600" />
                      ) : (
                        <Flag className="mr-2 h-4 w-4 text-red-600" />
                      )}
                      {card.flagged ? 'Unflag' : 'Flag'}
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={() => handleViewCard(card.externalId)}>
                      <FileText className="mr-2 h-4 w-4" />
                      View Card
                    </DropdownMenuItem>
                    <DropdownMenuItem
                      onClick={() =>
                        setPendingAction({
                          externalId: card.externalId,
                          action: card.deleted ? 'unarchive' : 'archive',
                        })
                      }
                      className="text-red-500"
                    >
                      <Trash2 className="mr-2 h-4 w-4" />
                      {card.deleted ? 'Unarchive' : 'Archive'}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>

              {(card.locked || card.flagged || card.deleted) && (
                <div className="flex gap-2 flex-wrap">
                  {card.locked && (
                    <span className="px-2 py-1 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
                      Locked
                    </span>
                  )}
                  {card.flagged && (
                    <span className="px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-700">
                      Flagged
                    </span>
                  )}
                  {card.deleted && (
                    <span className="px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-700">
                      Archived
                    </span>
                  )}
                </div>
              )}

              <div className="text-xs text-gray-500">
                Created {new Date(card.createdAt).toLocaleDateString()}
              </div>
            </div>
          ))
        )}
      </div>

      <div className="flex justify-center items-center gap-2 mt-auto pb-4">
        <Button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>
          Prev
        </Button>
        <span className="text-sm text-gray-600">
          Page {page} of {totalPages}
        </span>
        <Button
          onClick={() => setPage(p => Math.min(totalPages, p + 1))}
          disabled={page === totalPages}
        >
          Next
        </Button>
      </div>
    </div>
  );
};

export default withAuth(ManageCards);
