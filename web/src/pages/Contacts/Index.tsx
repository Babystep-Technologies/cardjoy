import React, { useMemo, useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { CalendarHeart, Pencil, Plus, Send, Trash2, UserPlus } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { IntentPickerDialog } from '@/components/IntentPickerDialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

type Occasion = {
  id: string;
  kind: string;
  occursOn: string;
  recurring: boolean;
  nextOccurrence: string;
};

type Contact = {
  id: string;
  name: string;
  email: string | null;
  relationship: string | null;
  occasions: Occasion[];
};

type UpcomingOccasion = Occasion & {
  contact: { id: string; name: string };
};

const CONTACT_FIELDS = gql`
  fragment ContactFields on Contact {
    id
    name
    email
    relationship
    occasions {
      id
      kind
      occursOn
      recurring
      nextOccurrence
    }
  }
`;

const MY_CONTACTS = gql`
  query MyContacts {
    myContacts {
      ...ContactFields
    }
  }
  ${CONTACT_FIELDS}
`;

const UPCOMING_OCCASIONS = gql`
  query UpcomingOccasions {
    upcomingOccasions {
      id
      kind
      occursOn
      recurring
      nextOccurrence
      contact {
        id
        name
      }
    }
  }
`;

// The card occasion vocabulary, shared with the occasion `kind` field on the API side.
const CARD_OCCASIONS = gql`
  query CardOccasions {
    cardOccasions
  }
`;

const CREATE_CONTACT = gql`
  mutation CreateContact($input: CreateContactInput!) {
    createContact(input: $input) {
      contact {
        ...ContactFields
      }
      errors
    }
  }
  ${CONTACT_FIELDS}
`;

const UPDATE_CONTACT = gql`
  mutation UpdateContact($input: UpdateContactInput!) {
    updateContact(input: $input) {
      contact {
        ...ContactFields
      }
      errors
    }
  }
  ${CONTACT_FIELDS}
`;

const DELETE_CONTACT = gql`
  mutation DeleteContact($input: DeleteContactInput!) {
    deleteContact(input: $input) {
      success
      errors
    }
  }
`;

const CREATE_OCCASION = gql`
  mutation CreateOccasion($input: CreateOccasionInput!) {
    createOccasion(input: $input) {
      occasion {
        id
      }
      errors
    }
  }
`;

const UPDATE_OCCASION = gql`
  mutation UpdateOccasion($input: UpdateOccasionInput!) {
    updateOccasion(input: $input) {
      occasion {
        id
      }
      errors
    }
  }
`;

const DELETE_OCCASION = gql`
  mutation DeleteOccasion($input: DeleteOccasionInput!) {
    deleteOccasion(input: $input) {
      success
      errors
    }
  }
`;

// Occasion dates are plain "YYYY-MM-DD" strings with no time or zone. Build the Date from the parts
// so it renders on the intended calendar day regardless of the viewer's timezone.
function formatDate(iso: string): string {
  const [year, month, day] = iso.split('-').map(Number);
  return new Date(year, month - 1, day).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function daysUntil(iso: string): number {
  const [year, month, day] = iso.split('-').map(Number);
  const target = new Date(year, month - 1, day);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return Math.round((target.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
}

function relativeLabel(iso: string): string {
  const days = daysUntil(iso);
  if (days <= 0) return 'Today';
  if (days === 1) return 'Tomorrow';
  return `in ${days} days`;
}

type ContactDraft = { name: string; email: string; relationship: string };
type OccasionDraft = { kind: string; occursOn: string; recurring: boolean };

const Contacts: React.FC = () => {
  const {
    data: contactsData,
    loading: contactsLoading,
    error: contactsError,
    refetch: refetchContacts,
  } = useQuery(MY_CONTACTS, { fetchPolicy: 'cache-and-network' });

  const { data: upcomingData, refetch: refetchUpcoming } = useQuery(UPCOMING_OCCASIONS, {
    fetchPolicy: 'cache-and-network',
  });

  const { data: occasionKindsData } = useQuery(CARD_OCCASIONS);

  const contacts: Contact[] = useMemo(() => contactsData?.myContacts ?? [], [contactsData]);
  const upcoming: UpcomingOccasion[] = useMemo(
    () => upcomingData?.upcomingOccasions ?? [],
    [upcomingData]
  );
  const occasionKinds: string[] = occasionKindsData?.cardOccasions ?? [];

  const [createContact] = useMutation(CREATE_CONTACT);
  const [updateContact] = useMutation(UPDATE_CONTACT);
  const [deleteContact] = useMutation(DELETE_CONTACT);
  const [createOccasion] = useMutation(CREATE_OCCASION);
  const [updateOccasion] = useMutation(UPDATE_OCCASION);
  const [deleteOccasion] = useMutation(DELETE_OCCASION);

  // Contact dialog: null draft closed; `id` null means "add", set means "edit".
  const [contactDialog, setContactDialog] = useState<{
    id: string | null;
    draft: ContactDraft;
  } | null>(null);
  // Occasion dialog carries the owning contact plus (when editing) the occasion id.
  const [occasionDialog, setOccasionDialog] = useState<{
    contactId: string;
    occasionId: string | null;
    draft: OccasionDraft;
  } | null>(null);
  const [saving, setSaving] = useState(false);

  const refetchAll = async () => {
    await Promise.all([refetchContacts(), refetchUpcoming()]);
  };

  const openAddContact = () =>
    setContactDialog({ id: null, draft: { name: '', email: '', relationship: '' } });

  const openEditContact = (contact: Contact) =>
    setContactDialog({
      id: contact.id,
      draft: {
        name: contact.name,
        email: contact.email ?? '',
        relationship: contact.relationship ?? '',
      },
    });

  const openAddOccasion = (contactId: string) =>
    setOccasionDialog({
      contactId,
      occasionId: null,
      draft: { kind: occasionKinds[0] ?? '', occursOn: '', recurring: true },
    });

  const openEditOccasion = (contactId: string, occasion: Occasion) =>
    setOccasionDialog({
      contactId,
      occasionId: occasion.id,
      draft: { kind: occasion.kind, occursOn: occasion.occursOn, recurring: occasion.recurring },
    });

  const handleSaveContact = async () => {
    if (!contactDialog) return;
    const { id, draft } = contactDialog;
    if (!draft.name.trim()) {
      toast.error('Please enter a name');
      return;
    }
    setSaving(true);
    try {
      const variables = {
        input: {
          ...(id ? { contactId: id } : {}),
          name: draft.name.trim(),
          email: draft.email.trim(),
          relationship: draft.relationship.trim(),
        },
      };
      const { data } = id ? await updateContact({ variables }) : await createContact({ variables });
      const errors = id ? data?.updateContact?.errors : data?.createContact?.errors;
      if (errors && errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success(id ? 'Contact updated' : 'Contact added');
      setContactDialog(null);
      await refetchAll();
    } catch {
      toast.error('Something went wrong. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteContact = async (contact: Contact) => {
    if (!window.confirm(`Delete ${contact.name} and all their occasions?`)) return;
    try {
      const { data } = await deleteContact({ variables: { input: { contactId: contact.id } } });
      const errors = data?.deleteContact?.errors;
      if (errors && errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success('Contact deleted');
      await refetchAll();
    } catch {
      toast.error('Failed to delete contact');
    }
  };

  const handleSaveOccasion = async () => {
    if (!occasionDialog) return;
    const { contactId, occasionId, draft } = occasionDialog;
    if (!draft.kind) {
      toast.error('Please pick an occasion type');
      return;
    }
    if (!draft.occursOn) {
      toast.error('Please pick a date');
      return;
    }
    setSaving(true);
    try {
      const variables = {
        input: occasionId
          ? { occasionId, kind: draft.kind, occursOn: draft.occursOn, recurring: draft.recurring }
          : { contactId, kind: draft.kind, occursOn: draft.occursOn, recurring: draft.recurring },
      };
      const { data } = occasionId
        ? await updateOccasion({ variables })
        : await createOccasion({ variables });
      const errors = occasionId ? data?.updateOccasion?.errors : data?.createOccasion?.errors;
      if (errors && errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success(occasionId ? 'Occasion updated' : 'Occasion added');
      setOccasionDialog(null);
      await refetchAll();
    } catch {
      toast.error('Something went wrong. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteOccasion = async (occasion: Occasion) => {
    if (!window.confirm(`Delete this ${occasion.kind.toLowerCase()} occasion?`)) return;
    try {
      const { data } = await deleteOccasion({ variables: { input: { occasionId: occasion.id } } });
      const errors = data?.deleteOccasion?.errors;
      if (errors && errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success('Occasion deleted');
      await refetchAll();
    } catch {
      toast.error('Failed to delete occasion');
    }
  };

  if (contactsLoading && contacts.length === 0) return <LoadingScreen />;
  if (contactsError && contacts.length === 0) return <ErrorScreen />;

  return (
    <div className="min-h-[calc(100vh-4rem)] bg-gradient-to-br from-purple-50 via-pink-50 to-blue-50 px-4 py-8">
      <Toaster />
      <div className="mx-auto w-full max-w-4xl">
        <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Contacts</h1>
            <p className="mt-1 text-gray-600">
              Keep track of the people you care about and their special days — so CardJoy can remind
              you to send a card.
            </p>
          </div>
          <Button onClick={openAddContact} className="shrink-0">
            <UserPlus className="mr-2 h-4 w-4" />
            Add contact
          </Button>
        </div>

        {/* Upcoming occasions */}
        <section className="mb-8">
          <h2 className="mb-3 flex items-center gap-2 text-lg font-semibold text-gray-800">
            <CalendarHeart className="h-5 w-5 text-pink-500" />
            Upcoming
          </h2>
          {upcoming.length === 0 ? (
            <p className="rounded-lg border border-dashed border-gray-300 bg-white/60 p-4 text-sm text-gray-500">
              No occasions coming up in the next 30 days.
            </p>
          ) : (
            <ul className="grid gap-3 sm:grid-cols-2">
              {upcoming.map(occasion => (
                <li
                  key={occasion.id}
                  className="flex items-center justify-between gap-3 rounded-lg border border-gray-200 bg-white p-4 shadow-sm"
                >
                  <div className="min-w-0">
                    <p className="truncate font-medium text-gray-900">{occasion.contact.name}</p>
                    <p className="text-sm text-gray-500">
                      {occasion.kind} · {relativeLabel(occasion.nextOccurrence)}
                    </p>
                    <p className="text-xs text-gray-400">{formatDate(occasion.nextOccurrence)}</p>
                  </div>
                  {/* Different card types have different flows, so let the user pick one; the
                      occasion is carried through so the create flow opens pre-set. */}
                  <IntentPickerDialog occasion={occasion.kind}>
                    <Button size="sm" variant="outline" className="shrink-0">
                      <Send className="mr-1.5 h-3.5 w-3.5" />
                      Send a card
                    </Button>
                  </IntentPickerDialog>
                </li>
              ))}
            </ul>
          )}
        </section>

        {/* Contacts */}
        <section>
          <h2 className="mb-3 text-lg font-semibold text-gray-800">Contacts</h2>
          {contacts.length === 0 ? (
            <div className="rounded-lg border border-dashed border-gray-300 bg-white/60 p-8 text-center">
              <p className="text-gray-600">You haven&apos;t added anyone yet.</p>
              <Button onClick={openAddContact} variant="outline" className="mt-4">
                <UserPlus className="mr-2 h-4 w-4" />
                Add your first contact
              </Button>
            </div>
          ) : (
            <ul className="space-y-4">
              {contacts.map(contact => (
                <li
                  key={contact.id}
                  className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-lg font-semibold text-gray-900">{contact.name}</p>
                      <p className="text-sm text-gray-500">
                        {[contact.relationship, contact.email].filter(Boolean).join(' · ') ||
                          'No details'}
                      </p>
                    </div>
                    <div className="flex shrink-0 gap-1">
                      <Button
                        size="icon"
                        variant="ghost"
                        aria-label={`Edit ${contact.name}`}
                        onClick={() => openEditContact(contact)}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        size="icon"
                        variant="ghost"
                        aria-label={`Delete ${contact.name}`}
                        onClick={() => handleDeleteContact(contact)}
                      >
                        <Trash2 className="h-4 w-4 text-red-500" />
                      </Button>
                    </div>
                  </div>

                  <div className="mt-3 border-t border-gray-100 pt-3">
                    {contact.occasions.length === 0 ? (
                      <p className="text-sm text-gray-400">No occasions yet.</p>
                    ) : (
                      <ul className="space-y-2">
                        {contact.occasions.map(occasion => (
                          <li
                            key={occasion.id}
                            className="flex items-center justify-between gap-2 text-sm"
                          >
                            <span className="text-gray-700">
                              <span className="font-medium">{occasion.kind}</span>{' '}
                              <span className="text-gray-500">
                                — {formatDate(occasion.occursOn)}
                                {occasion.recurring && ' (yearly)'}
                              </span>
                            </span>
                            <span className="flex shrink-0 gap-1">
                              <Button
                                size="icon"
                                variant="ghost"
                                aria-label={`Edit ${occasion.kind} occasion`}
                                onClick={() => openEditOccasion(contact.id, occasion)}
                              >
                                <Pencil className="h-3.5 w-3.5" />
                              </Button>
                              <Button
                                size="icon"
                                variant="ghost"
                                aria-label={`Delete ${occasion.kind} occasion`}
                                onClick={() => handleDeleteOccasion(occasion)}
                              >
                                <Trash2 className="h-3.5 w-3.5 text-red-500" />
                              </Button>
                            </span>
                          </li>
                        ))}
                      </ul>
                    )}
                    <Button
                      size="sm"
                      variant="ghost"
                      className="mt-2 text-pink-600 hover:text-pink-700"
                      onClick={() => openAddOccasion(contact.id)}
                    >
                      <Plus className="mr-1 h-4 w-4" />
                      Add occasion
                    </Button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>

      {/* Contact add/edit dialog */}
      <Dialog open={!!contactDialog} onOpenChange={open => !open && setContactDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{contactDialog?.id ? 'Edit contact' : 'Add contact'}</DialogTitle>
            <DialogDescription>
              Someone whose occasions you want CardJoy to help you remember.
            </DialogDescription>
          </DialogHeader>
          {contactDialog && (
            <div className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="contact-name">Name</Label>
                <Input
                  id="contact-name"
                  value={contactDialog.draft.name}
                  onChange={e =>
                    setContactDialog({
                      ...contactDialog,
                      draft: { ...contactDialog.draft, name: e.target.value },
                    })
                  }
                  placeholder="Jane Doe"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="contact-relationship">Relationship</Label>
                <Input
                  id="contact-relationship"
                  value={contactDialog.draft.relationship}
                  onChange={e =>
                    setContactDialog({
                      ...contactDialog,
                      draft: { ...contactDialog.draft, relationship: e.target.value },
                    })
                  }
                  placeholder="Coworker, sister, friend…"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="contact-email">Email</Label>
                <Input
                  id="contact-email"
                  type="email"
                  value={contactDialog.draft.email}
                  onChange={e =>
                    setContactDialog({
                      ...contactDialog,
                      draft: { ...contactDialog.draft, email: e.target.value },
                    })
                  }
                  placeholder="jane@example.com"
                />
              </div>
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setContactDialog(null)} disabled={saving}>
              Cancel
            </Button>
            <Button onClick={handleSaveContact} disabled={saving}>
              {saving ? 'Saving…' : 'Save'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Occasion add/edit dialog */}
      <Dialog open={!!occasionDialog} onOpenChange={open => !open && setOccasionDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {occasionDialog?.occasionId ? 'Edit occasion' : 'Add occasion'}
            </DialogTitle>
          </DialogHeader>
          {occasionDialog && (
            <div className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="occasion-kind">Occasion</Label>
                <Select
                  value={occasionDialog.draft.kind}
                  onValueChange={value =>
                    setOccasionDialog({
                      ...occasionDialog,
                      draft: { ...occasionDialog.draft, kind: value },
                    })
                  }
                >
                  <SelectTrigger id="occasion-kind">
                    <SelectValue placeholder="Pick an occasion" />
                  </SelectTrigger>
                  <SelectContent>
                    {occasionKinds.map(kind => (
                      <SelectItem key={kind} value={kind}>
                        {kind}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="occasion-date">Date</Label>
                <Input
                  id="occasion-date"
                  type="date"
                  value={occasionDialog.draft.occursOn}
                  onChange={e =>
                    setOccasionDialog({
                      ...occasionDialog,
                      draft: { ...occasionDialog.draft, occursOn: e.target.value },
                    })
                  }
                />
              </div>
              <div className="flex items-center justify-between">
                <div>
                  <Label>Repeats every year</Label>
                  <p className="text-xs text-gray-500">
                    On for birthdays and anniversaries; off for one-time events.
                  </p>
                </div>
                <Switch
                  aria-label="Repeats every year"
                  checked={occasionDialog.draft.recurring}
                  onCheckedChange={checked =>
                    setOccasionDialog({
                      ...occasionDialog,
                      draft: { ...occasionDialog.draft, recurring: checked },
                    })
                  }
                />
              </div>
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setOccasionDialog(null)} disabled={saving}>
              Cancel
            </Button>
            <Button onClick={handleSaveOccasion} disabled={saving}>
              {saving ? 'Saving…' : 'Save'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default withAuth(Contacts);
