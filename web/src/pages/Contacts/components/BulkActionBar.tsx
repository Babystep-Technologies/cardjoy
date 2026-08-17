import React, { useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { ListPlus, Plus, X } from 'lucide-react';
import { toast } from 'sonner';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import type { ContactListSummary } from '../types';

// Both membership mutations take arrays: adding forty people to a list is one round trip,
// never forty.
const ADD_CONTACTS_TO_LIST = gql`
  mutation AddContactsToList($input: AddContactsToListInput!) {
    addContactsToList(input: $input) {
      contactList {
        id
      }
      errors
    }
  }
`;

const REMOVE_CONTACTS_FROM_LIST = gql`
  mutation RemoveContactsFromList($input: RemoveContactsFromListInput!) {
    removeContactsFromList(input: $input) {
      contactList {
        id
      }
      errors
    }
  }
`;

const CREATE_CONTACT_LIST = gql`
  mutation CreateContactListForSelection($input: CreateContactListInput!) {
    createContactList(input: $input) {
      contactList {
        id
      }
      errors
    }
  }
`;

type BulkActionBarProps = {
  selectedIds: string[];
  lists: ContactListSummary[];
  /** The list the table is filtered to, if any — lets "remove" skip a menu. */
  activeList: ContactListSummary | null;
  onClearSelection: () => void;
  /** Refetch contacts and lists; membership changes both. */
  onChanged: () => Promise<unknown>;
};

const BulkActionBar: React.FC<BulkActionBarProps> = ({
  selectedIds,
  lists,
  activeList,
  onClearSelection,
  onChanged,
}) => {
  const [addContactsToList] = useMutation(ADD_CONTACTS_TO_LIST);
  const [removeContactsFromList] = useMutation(REMOVE_CONTACTS_FROM_LIST);
  const [createContactList] = useMutation(CREATE_CONTACT_LIST);

  const [newListName, setNewListName] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const count = selectedIds.length;
  const contactsLabel = count === 1 ? '1 contact' : `${count} contacts`;

  const handleAdd = async (list: ContactListSummary) => {
    setBusy(true);
    try {
      const { data } = await addContactsToList({
        variables: { input: { listId: list.id, contactIds: selectedIds } },
      });
      const errors = data?.addContactsToList?.errors;
      if (errors && errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success(`Added ${contactsLabel} to ${list.name}`);
      onClearSelection();
      await onChanged();
    } catch {
      toast.error('Something went wrong. Please try again.');
    } finally {
      setBusy(false);
    }
  };

  const handleRemove = async (list: ContactListSummary) => {
    setBusy(true);
    try {
      const { data } = await removeContactsFromList({
        variables: { input: { listId: list.id, contactIds: selectedIds } },
      });
      const errors = data?.removeContactsFromList?.errors;
      if (errors && errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success(`Removed ${contactsLabel} from ${list.name}`);
      onClearSelection();
      await onChanged();
    } catch {
      toast.error('Something went wrong. Please try again.');
    } finally {
      setBusy(false);
    }
  };

  // Creating a list from a selection is the common first move — "these forty people are my
  // holiday list" — so the new list is populated in the same gesture.
  const handleCreateAndAdd = async () => {
    const name = (newListName ?? '').trim();
    if (!name) {
      toast.error('Please enter a list name');
      return;
    }

    setBusy(true);
    try {
      const { data } = await createContactList({ variables: { input: { name } } });
      const errors = data?.createContactList?.errors;
      if (errors && errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      const listId = data?.createContactList?.contactList?.id;
      if (!listId) {
        toast.error('Something went wrong. Please try again.');
        return;
      }

      const { data: addData } = await addContactsToList({
        variables: { input: { listId, contactIds: selectedIds } },
      });
      const addErrors = addData?.addContactsToList?.errors;
      if (addErrors && addErrors.length > 0) {
        toast.error(addErrors.join(', '));
        return;
      }

      toast.success(`Created ${name} with ${contactsLabel}`);
      setNewListName(null);
      onClearSelection();
      await onChanged();
    } catch {
      toast.error('Something went wrong. Please try again.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <div className="mb-3 flex flex-wrap items-center gap-2 rounded-lg border border-pink-200 bg-pink-50 px-3 py-2">
        <span className="text-sm font-medium text-pink-900">{contactsLabel} selected</span>
        <div className="ml-auto flex flex-wrap items-center gap-2">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button size="sm" variant="outline" disabled={busy} className="bg-white">
                <Plus className="mr-1.5 h-4 w-4" />
                Add to list…
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="max-h-72 overflow-y-auto">
              {lists.length > 0 && (
                <>
                  <DropdownMenuLabel>Add to</DropdownMenuLabel>
                  {lists.map(list => (
                    <DropdownMenuItem key={list.id} onSelect={() => void handleAdd(list)}>
                      {list.name}
                    </DropdownMenuItem>
                  ))}
                  <DropdownMenuSeparator />
                </>
              )}
              <DropdownMenuItem onSelect={() => setNewListName('')}>
                <ListPlus className="mr-2 h-4 w-4" />
                New list…
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>

          {activeList ? (
            <Button
              size="sm"
              variant="outline"
              className="bg-white"
              disabled={busy}
              onClick={() => void handleRemove(activeList)}
            >
              Remove from {activeList.name}
            </Button>
          ) : (
            lists.length > 0 && (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button size="sm" variant="outline" disabled={busy} className="bg-white">
                    Remove from list…
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="max-h-72 overflow-y-auto">
                  <DropdownMenuLabel>Remove from</DropdownMenuLabel>
                  {lists.map(list => (
                    <DropdownMenuItem key={list.id} onSelect={() => void handleRemove(list)}>
                      {list.name}
                    </DropdownMenuItem>
                  ))}
                </DropdownMenuContent>
              </DropdownMenu>
            )
          )}

          <Button
            size="sm"
            variant="ghost"
            onClick={onClearSelection}
            disabled={busy}
            aria-label="Clear selection"
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      </div>

      <Dialog open={newListName !== null} onOpenChange={open => !open && setNewListName(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>New list</DialogTitle>
            <DialogDescription>
              The {contactsLabel} you selected will be added to it.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-1.5">
            <Label htmlFor="bulk-new-list-name">Name</Label>
            <Input
              id="bulk-new-list-name"
              autoFocus
              value={newListName ?? ''}
              onChange={e => setNewListName(e.target.value)}
              onKeyDown={e => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  void handleCreateAndAdd();
                }
              }}
              placeholder="Holiday cards 2026"
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setNewListName(null)} disabled={busy}>
              Cancel
            </Button>
            <Button onClick={handleCreateAndAdd} disabled={busy}>
              {busy ? 'Creating…' : 'Create list'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
};

export default BulkActionBar;
