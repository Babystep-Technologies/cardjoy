/**
 * Adding a missing address without leaving the send flow (#151).
 *
 * The alternative — "this contact has no address, go to Contacts and fix it" —
 * costs the user their place in a flow they were part-way through, and in
 * practice costs the card. Four people missing an address is the normal state
 * of an address book the first time someone mails from it, so fixing one is a
 * normal step of the flow rather than an error recovery.
 *
 * The same `AddressFields` the Contacts page uses, and the same client-side
 * all-or-nothing check, so a half-filled address is caught here rather than
 * coming back from `Contact`'s validation as a server error.
 */
import React, { useState } from 'react';
import { useMutation } from '@apollo/client';
import { toast } from 'sonner';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import AddressFields from '@/pages/Contacts/components/AddressFields';
import {
  addressDraftFrom,
  addressInput,
  hasAddressInput,
  validateAddress,
  type AddressDraft,
  type AddressErrors,
} from '@/lib/address';
import { UPDATE_CONTACT_ADDRESS } from './queries';
import type { SendContact } from './types';

type AddressDialogProps = {
  /** The contact being fixed; null closes the dialog. */
  contact: SendContact | null;
  onClose: () => void;
  /** Refetch the flow's data — the contact's `mailable` and zone both moved. */
  onSaved: () => Promise<unknown> | void;
};

interface UpdateContactResponse {
  updateContact: { contact: SendContact | null; errors: string[] };
}

export const AddressDialog: React.FC<AddressDialogProps> = ({ contact, onClose, onSaved }) => {
  const [draft, setDraft] = useState<AddressDraft | null>(null);
  const [errors, setErrors] = useState<AddressErrors>({});
  const [saving, setSaving] = useState(false);
  const [updateContact] = useMutation<UpdateContactResponse>(UPDATE_CONTACT_ADDRESS);

  // Seeded from whichever contact the dialog was opened for, and reset when it
  // changes — the dialog is reused across every row in the list.
  const [seededFor, setSeededFor] = useState<string | null>(null);
  if (contact && seededFor !== contact.id) {
    setSeededFor(contact.id);
    setDraft(addressDraftFrom(contact));
    setErrors({});
  }

  const handleSave = async () => {
    if (!contact || !draft) return;

    if (!hasAddressInput(draft)) {
      setErrors({ line1: 'Enter an address so we know where to send this card' });
      return;
    }

    const problems = validateAddress(draft);
    setErrors(problems);
    if (Object.keys(problems).length > 0) return;

    setSaving(true);
    try {
      const { data } = await updateContact({
        variables: { input: { contactId: contact.id, ...addressInput(draft) } },
      });
      const failures = data?.updateContact?.errors ?? [];
      if (failures.length > 0) {
        toast.error(failures.join(' '));
        return;
      }

      // The address is what decides the price — its zone is only known once
      // PostGrid has seen it — so the flow re-reads rather than patching a row.
      await onSaved();
      toast.success(`Address saved for ${contact.name}`);
      onClose();
    } catch {
      toast.error('Could not save that address. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={!!contact} onOpenChange={open => !open && !saving && onClose()}>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Add an address for {contact?.name}</DialogTitle>
          <DialogDescription>
            This saves to your address book, so you only have to do it once.
          </DialogDescription>
        </DialogHeader>

        {draft && (
          <AddressFields
            value={draft}
            onChange={patch => {
              setErrors({});
              setDraft(current => current && { ...current, ...patch });
            }}
            errors={errors}
            defaultOpen
          />
        )}

        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={saving}>
            Cancel
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? 'Saving…' : 'Save address'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default AddressDialog;
