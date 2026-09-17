/**
 * Stage 1 — who is getting a card (#151).
 *
 * Two ways in, both live: tick a contact, or tick a contact list and get its
 * members. The list stays live because the selection stores the *list*, not the
 * ids it happened to contain when it was ticked (see `selection.ts`).
 *
 * **Nobody is hidden.** A contact with no deliverable address is rendered
 * greyed, with the reason spelled out and a button that fixes it in place. The
 * temptation is to filter them out — the list looks tidier and every row is
 * sendable — but the four people missing an address are exactly the four the
 * user wants to know about, and a filtered list tells them nothing is wrong
 * right up until the count at the bottom says 38 instead of 42.
 */
import React, { useMemo, useState } from 'react';
import { AlertCircle, ListChecks, MapPinPlus, Search } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import { formatAddressSummary } from '@/lib/address';
import { pluralize } from '@/lib/money';
import MailableCount from './MailableCount';
import AddressDialog from './AddressDialog';
import { isSelected, resolveSelection, toggleContact, toggleList } from './selection';
import type { Selection, SendContact, SendContactList } from './types';

type RecipientsStageProps = {
  contacts: SendContact[];
  lists: SendContactList[];
  selection: Selection;
  onSelectionChange: (selection: Selection) => void;
  onRefetch: () => Promise<unknown> | void;
  onContinue: () => void;
};

/**
 * Why this contact can't be mailed, in the user's terms.
 *
 * `mailable` is the address being *complete*; `addressVerificationStatus` is
 * PostGrid's verdict on whether it exists. They fail differently and need
 * different things from the user, so they are told apart rather than collapsed
 * into "bad address".
 */
function blockedReason(contact: SendContact): string | null {
  if (!contact.mailable) return 'No mailing address yet';
  if (contact.addressVerificationStatus === 'undeliverable') {
    return "Our print partner couldn't deliver to this address";
  }
  return null;
}

export const RecipientsStage: React.FC<RecipientsStageProps> = ({
  contacts,
  lists,
  selection,
  onSelectionChange,
  onRefetch,
  onContinue,
}) => {
  const [search, setSearch] = useState('');
  const [addressFor, setAddressFor] = useState<SendContact | null>(null);

  const selected = useMemo(() => resolveSelection(contacts, selection), [contacts, selection]);
  const mailableSelected = useMemo(
    () => selected.filter(contact => !blockedReason(contact)),
    [selected]
  );

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return contacts;
    return contacts.filter(
      contact =>
        contact.name.toLowerCase().includes(needle) ||
        (contact.email ?? '').toLowerCase().includes(needle)
    );
  }, [contacts, search]);

  // The dialog holds a snapshot; after a save the refetched contact is the one
  // whose `mailable` moved, so re-point at it rather than at the stale copy.
  const addressDialogContact = addressFor
    ? (contacts.find(contact => contact.id === addressFor.id) ?? addressFor)
    : null;

  return (
    <div className="space-y-6">
      <MailableCount selected={selected.length} mailable={mailableSelected.length} />

      {lists.length > 0 && (
        <section>
          <h2 className="mb-2 flex items-center gap-2 text-sm font-semibold text-gray-800">
            <ListChecks className="h-4 w-4 text-pink-500" />
            Contact lists
          </h2>
          <p className="mb-3 text-xs text-gray-500">
            Picking a list stays live — anyone you add to it later is included in this send too.
          </p>
          <div className="flex flex-wrap gap-2">
            {lists.map(list => {
              const active = selection.listIds.includes(list.id);
              return (
                <button
                  key={list.id}
                  type="button"
                  aria-pressed={active}
                  onClick={() => onSelectionChange(toggleList(list.id, selection, contacts))}
                  className={cn(
                    'rounded-full border px-3.5 py-1.5 text-sm transition-colors',
                    active
                      ? 'border-gray-900 bg-gray-900 text-white'
                      : 'border-gray-300 bg-white text-gray-700 hover:border-gray-400'
                  )}
                >
                  {list.name}
                  <span className={cn('ml-2 text-xs', active ? 'text-gray-300' : 'text-gray-500')}>
                    {list.mailableContactsCount}/{list.contactsCount} with an address
                  </span>
                </button>
              );
            })}
          </div>
        </section>
      )}

      <section>
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-sm font-semibold text-gray-800">
            Everyone in your address book
            <span className="ml-2 font-normal text-gray-500">
              {pluralize(contacts.length, 'contact')}
            </span>
          </h2>
          <div className="relative w-full sm:w-64">
            <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-gray-400" />
            <Input
              value={search}
              onChange={event => setSearch(event.target.value)}
              placeholder="Search by name or email"
              aria-label="Search contacts"
              className="pl-9"
            />
          </div>
        </div>

        {visible.length === 0 ? (
          <p className="rounded-lg border border-dashed border-gray-300 bg-white/60 p-8 text-center text-gray-600">
            {contacts.length === 0
              ? "You haven't added anyone to your address book yet."
              : 'No contacts match that search.'}
          </p>
        ) : (
          <ul className="divide-y divide-gray-100 overflow-hidden rounded-lg border border-gray-200 bg-white">
            {visible.map(contact => {
              const reason = blockedReason(contact);
              const checked = isSelected(contact, selection);
              const address = formatAddressSummary(contact);

              return (
                <li
                  key={contact.id}
                  className={cn(
                    'flex items-start gap-3 px-4 py-3',
                    // Greyed, not hidden and not disabled: the row still ticks,
                    // so someone can queue a person up and fix the address next.
                    reason && 'bg-gray-50'
                  )}
                >
                  <input
                    type="checkbox"
                    id={`recipient-${contact.id}`}
                    checked={checked}
                    onChange={() => onSelectionChange(toggleContact(contact, selection))}
                    className="mt-1 h-4 w-4 shrink-0 rounded border-gray-300 accent-gray-900"
                  />
                  <div className="min-w-0 flex-1">
                    <label
                      htmlFor={`recipient-${contact.id}`}
                      className={cn(
                        'cursor-pointer font-medium',
                        reason ? 'text-gray-500' : 'text-gray-900'
                      )}
                    >
                      {contact.name}
                    </label>

                    {contact.contactLists.length > 0 && (
                      <span className="ml-2 inline-flex flex-wrap gap-1 align-middle">
                        {contact.contactLists.map(list => (
                          <Badge key={list.id} variant="secondary" className="text-[10px]">
                            {list.name}
                          </Badge>
                        ))}
                      </span>
                    )}

                    {reason ? (
                      <p className="mt-0.5 flex items-center gap-1.5 text-sm text-amber-700">
                        <AlertCircle className="h-3.5 w-3.5 shrink-0" />
                        {reason}
                      </p>
                    ) : (
                      <p className="mt-0.5 truncate text-sm text-gray-500">{address}</p>
                    )}
                  </div>

                  {reason && (
                    <Button
                      variant="outline"
                      size="sm"
                      className="shrink-0"
                      onClick={() => setAddressFor(contact)}
                    >
                      <MapPinPlus className="mr-1.5 h-3.5 w-3.5" />
                      {contact.mailable ? 'Fix address' : 'Add address'}
                    </Button>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-4">
        <p className="text-sm text-gray-500">
          {mailableSelected.length === 0
            ? 'Select at least one contact with a deliverable address to continue.'
            : `Next: review a proof of the card before anything is printed.`}
        </p>
        <Button onClick={onContinue} disabled={mailableSelected.length === 0}>
          Continue to proof
        </Button>
      </div>

      <AddressDialog
        contact={addressDialogContact}
        onClose={() => setAddressFor(null)}
        onSaved={onRefetch}
      />
    </div>
  );
};

export default RecipientsStage;
