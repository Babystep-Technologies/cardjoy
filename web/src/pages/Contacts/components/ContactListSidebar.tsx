import React, { useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { ListPlus, MoreHorizontal, Pencil, Trash2, Users } from 'lucide-react';
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
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { cn } from '@/lib/utils';
import type { ContactListSummary } from '../types';

const CREATE_CONTACT_LIST = gql`
  mutation CreateContactList($input: CreateContactListInput!) {
    createContactList(input: $input) {
      contactList {
        id
      }
      errors
    }
  }
`;

const RENAME_CONTACT_LIST = gql`
  mutation RenameContactList($input: RenameContactListInput!) {
    renameContactList(input: $input) {
      contactList {
        id
      }
      errors
    }
  }
`;

const DELETE_CONTACT_LIST = gql`
  mutation DeleteContactList($input: DeleteContactListInput!) {
    deleteContactList(input: $input) {
      success
      errors
    }
  }
`;

type ContactListSidebarProps = {
  lists: ContactListSummary[];
  /** null means "All contacts". */
  selectedListId: string | null;
  onSelectList: (listId: string | null) => void;
  totalContacts: number;
  mailableContacts: number;
  /** Refetch contacts and lists — a delete changes both. */
  onChanged: () => Promise<unknown>;
};

// "38 of 42 have an address" is what tells the user whether a send would actually reach
// everyone on the list, so both numbers are always shown together.
function countsLabel(total: number, mailable: number): string {
  if (total === 0) return 'No contacts yet';
  const contacts = total === 1 ? '1 contact' : `${total} contacts`;
  return `${contacts} · ${mailable} with addresses`;
}

const ContactListSidebar: React.FC<ContactListSidebarProps> = ({
  lists,
  selectedListId,
  onSelectList,
  totalContacts,
  mailableContacts,
  onChanged,
}) => {
  const [createContactList] = useMutation(CREATE_CONTACT_LIST);
  const [renameContactList] = useMutation(RENAME_CONTACT_LIST);
  const [deleteContactList] = useMutation(DELETE_CONTACT_LIST);

  // One dialog for both create and rename: `id` null means create.
  const [nameDialog, setNameDialog] = useState<{ id: string | null; name: string } | null>(null);
  const [listToDelete, setListToDelete] = useState<ContactListSummary | null>(null);
  const [saving, setSaving] = useState(false);

  const handleSaveName = async () => {
    if (!nameDialog) return;
    const name = nameDialog.name.trim();
    if (!name) {
      toast.error('Please enter a list name');
      return;
    }

    setSaving(true);
    try {
      const { data } = nameDialog.id
        ? await renameContactList({ variables: { input: { id: nameDialog.id, name } } })
        : await createContactList({ variables: { input: { name } } });
      const errors = nameDialog.id
        ? data?.renameContactList?.errors
        : data?.createContactList?.errors;
      if (errors && errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success(nameDialog.id ? 'List renamed' : 'List created');
      setNameDialog(null);
      await onChanged();
    } catch {
      toast.error('Something went wrong. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!listToDelete) return;
    setSaving(true);
    try {
      const { data } = await deleteContactList({
        variables: { input: { id: listToDelete.id } },
      });
      const errors = data?.deleteContactList?.errors;
      if (errors && errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success('List deleted');
      // The table would otherwise keep filtering by a list that no longer exists.
      if (selectedListId === listToDelete.id) onSelectList(null);
      setListToDelete(null);
      await onChanged();
    } catch {
      toast.error('Failed to delete list');
    } finally {
      setSaving(false);
    }
  };

  const rowClasses = (active: boolean) =>
    cn(
      'w-full rounded-lg border px-3 py-2 text-left transition-colors',
      active
        ? 'border-pink-300 bg-pink-50 text-pink-900'
        : 'border-transparent text-gray-700 hover:bg-gray-50'
    );

  return (
    <aside className="lg:sticky lg:top-6">
      <div className="rounded-lg border border-gray-200 bg-white p-3 shadow-sm">
        <div className="mb-2 flex items-center justify-between gap-2 px-1">
          <h2 className="flex items-center gap-2 text-sm font-semibold text-gray-800">
            <Users className="h-4 w-4 text-pink-500" />
            Lists
          </h2>
          <Button
            size="icon"
            variant="ghost"
            className="h-7 w-7"
            aria-label="New list"
            onClick={() => setNameDialog({ id: null, name: '' })}
          >
            <ListPlus className="h-4 w-4" />
          </Button>
        </div>

        <button
          type="button"
          className={rowClasses(!selectedListId)}
          onClick={() => onSelectList(null)}
        >
          <span className="block truncate text-sm font-medium">All contacts</span>
          <span className="block text-xs text-gray-500">
            {countsLabel(totalContacts, mailableContacts)}
          </span>
        </button>

        {lists.length === 0 ? (
          <p className="mt-2 rounded-lg border border-dashed border-gray-300 p-3 text-xs text-gray-500">
            No lists yet. Group contacts into a list — &ldquo;Holiday cards&rdquo;, say — to address
            a card to all of them at once.
          </p>
        ) : (
          <ul className="mt-1 space-y-1">
            {lists.map(list => (
              <li key={list.id} className="flex items-center gap-1">
                <button
                  type="button"
                  className={cn(rowClasses(selectedListId === list.id), 'min-w-0 flex-1')}
                  onClick={() => onSelectList(list.id)}
                >
                  <span className="block truncate text-sm font-medium">{list.name}</span>
                  <span className="block text-xs text-gray-500">
                    {countsLabel(list.contactsCount, list.mailableContactsCount)}
                  </span>
                </button>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button
                      size="icon"
                      variant="ghost"
                      className="h-7 w-7 shrink-0"
                      aria-label={`Actions for ${list.name}`}
                    >
                      <MoreHorizontal className="h-4 w-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem
                      onSelect={() => setNameDialog({ id: list.id, name: list.name })}
                    >
                      <Pencil className="mr-2 h-4 w-4" />
                      Rename
                    </DropdownMenuItem>
                    <DropdownMenuItem variant="destructive" onSelect={() => setListToDelete(list)}>
                      <Trash2 className="mr-2 h-4 w-4" />
                      Delete
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Create / rename dialog */}
      <Dialog open={!!nameDialog} onOpenChange={open => !open && setNameDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{nameDialog?.id ? 'Rename list' : 'New list'}</DialogTitle>
            <DialogDescription>
              A list is a group of contacts you can address a card to in one go.
            </DialogDescription>
          </DialogHeader>
          {nameDialog && (
            <div className="space-y-1.5">
              <Label htmlFor="contact-list-name">Name</Label>
              <Input
                id="contact-list-name"
                autoFocus
                value={nameDialog.name}
                onChange={e => setNameDialog({ ...nameDialog, name: e.target.value })}
                onKeyDown={e => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    void handleSaveName();
                  }
                }}
                placeholder="Holiday cards 2026"
              />
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setNameDialog(null)} disabled={saving}>
              Cancel
            </Button>
            <Button onClick={handleSaveName} disabled={saving}>
              {saving ? 'Saving…' : 'Save'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete confirmation. Deleting a list keeps its contacts, which is not obvious —
          say so before the user commits. */}
      <Dialog open={!!listToDelete} onOpenChange={open => !open && setListToDelete(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete &ldquo;{listToDelete?.name}&rdquo;?</DialogTitle>
            <DialogDescription>
              This deletes the list only. The {listToDelete?.contactsCount ?? 0} contacts on it stay
              in your contacts — you can always put them on another list.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setListToDelete(null)} disabled={saving}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDelete} disabled={saving}>
              {saving ? 'Deleting…' : 'Delete list'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </aside>
  );
};

export default ContactListSidebar;
