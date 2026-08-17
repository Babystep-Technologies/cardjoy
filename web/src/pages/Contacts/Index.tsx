import React, { useCallback, useMemo, useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { CalendarHeart, Send, UserPlus } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { IntentPickerDialog } from '@/components/IntentPickerDialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Textarea } from '@/components/ui/textarea';
import { PhoneInput } from '@/components/PhoneInput';
import {
  DEFAULT_PHONE_COUNTRY,
  fromE164,
  toE164,
  type CountryCode as PhoneCountryCode,
} from '@/lib/phone';
import {
  addressDraftFrom,
  addressInput,
  emptyAddressDraft,
  hasAddressInput,
  validateAddress,
  type AddressDraft,
  type AddressErrors,
} from '@/lib/address';
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
import AddressFields from './components/AddressFields';
import BulkActionBar from './components/BulkActionBar';
import ContactListSidebar from './components/ContactListSidebar';
import ContactRow from './components/ContactRow';
import ContactsToolbar from './components/ContactsToolbar';
import { formatDate, relativeLabel, reminderLeadLabel } from './format';
import type {
  AddressFilter,
  Contact,
  ContactListSummary,
  Occasion,
  UpcomingOccasion,
} from './types';

const CONTACT_FIELDS = gql`
  fragment ContactFields on Contact {
    id
    name
    email
    relationship
    phone
    notes
    addressLine1
    addressLine2
    city
    region
    postalCode
    countryCode
    mailable
    contactLists {
      id
      name
    }
    occasions {
      id
      kind
      occursOn
      recurring
      nextOccurrence
      reminderLeadDays
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

// Counts only — membership comes off each contact's `contactLists`, so the sidebar never
// has to pull every list's members.
const MY_CONTACT_LISTS = gql`
  query MyContactLists {
    myContactLists {
      id
      name
      contactsCount
      mailableContactsCount
    }
  }
`;

const UPCOMING_OCCASIONS = gql`
  query UpcomingOccasions {
    upcomingOccasions {
      id
      kind
      occursOn
      recurring
      nextOccurrence
      reminderLeadDays
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

// The reminder lead times the API accepts, so the picker can't drift from the
// model's validation.
const REMINDER_LEAD_DAY_OPTIONS = gql`
  query OccasionReminderLeadDayOptions {
    occasionReminderLeadDayOptions
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

// `phone` holds the number as typed (national format); it's converted to E.164 on save.
type ContactDraft = {
  name: string;
  email: string;
  relationship: string;
  phone: string;
  phoneCountry: PhoneCountryCode;
  notes: string;
  address: AddressDraft;
};

const INVALID_PHONE_MESSAGE = "That doesn't look like a valid phone number";

// A week ahead — enough time to write something and still schedule it to land on the day.
const DEFAULT_REMINDER_LEAD_DAYS = 7;

// Radix's Select can't hold an empty value, so "reminders off" needs a sentinel.
const REMINDER_OFF = 'off';

type OccasionDraft = {
  kind: string;
  occursOn: string;
  recurring: boolean;
  reminderLeadDays: number | null;
};

const Contacts: React.FC = () => {
  const {
    data: contactsData,
    loading: contactsLoading,
    error: contactsError,
    refetch: refetchContacts,
  } = useQuery(MY_CONTACTS, { fetchPolicy: 'cache-and-network' });

  const { data: listsData, refetch: refetchLists } = useQuery(MY_CONTACT_LISTS, {
    fetchPolicy: 'cache-and-network',
  });

  const { data: upcomingData, refetch: refetchUpcoming } = useQuery(UPCOMING_OCCASIONS, {
    fetchPolicy: 'cache-and-network',
  });

  const { data: occasionKindsData } = useQuery(CARD_OCCASIONS);
  const { data: reminderOptionsData } = useQuery(REMINDER_LEAD_DAY_OPTIONS);

  const contacts: Contact[] = useMemo(() => contactsData?.myContacts ?? [], [contactsData]);
  const lists: ContactListSummary[] = useMemo(() => listsData?.myContactLists ?? [], [listsData]);
  const upcoming: UpcomingOccasion[] = useMemo(
    () => upcomingData?.upcomingOccasions ?? [],
    [upcomingData]
  );
  const occasionKinds: string[] = occasionKindsData?.cardOccasions ?? [];
  const reminderLeadOptions: number[] = reminderOptionsData?.occasionReminderLeadDayOptions ?? [];

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
  // Shown under the phone field once the user leaves it (or tries to save) with a bad number.
  const [phoneError, setPhoneError] = useState<string | null>(null);
  const [addressErrors, setAddressErrors] = useState<AddressErrors>({});

  // Which list the table is filtered to (null = everyone), and by address completeness.
  const [selectedListId, setSelectedListId] = useState<string | null>(null);
  const [addressFilter, setAddressFilter] = useState<AddressFilter>('all');
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

  const activeList = useMemo(
    () => lists.find(list => list.id === selectedListId) ?? null,
    [lists, selectedListId]
  );

  // The selected list narrows the population; the address filter then narrows what's shown.
  // Keeping them separate lets the filter chips count against the list, not the whole book.
  const listContacts = useMemo(
    () =>
      selectedListId
        ? contacts.filter(contact => contact.contactLists.some(list => list.id === selectedListId))
        : contacts,
    [contacts, selectedListId]
  );

  const visibleContacts = useMemo(() => {
    if (addressFilter === 'has') return listContacts.filter(contact => contact.mailable);
    if (addressFilter === 'missing') return listContacts.filter(contact => !contact.mailable);
    return listContacts;
  }, [listContacts, addressFilter]);

  const mailableCount = useMemo(
    () => contacts.filter(contact => contact.mailable).length,
    [contacts]
  );
  const listMailableCount = useMemo(
    () => listContacts.filter(contact => contact.mailable).length,
    [listContacts]
  );

  const visibleIds = useMemo(
    () => new Set(visibleContacts.map(contact => contact.id)),
    [visibleContacts]
  );
  // A contact hidden by the current filter shouldn't stay silently selected and get swept
  // into the next bulk action.
  const effectiveSelectedIds = useMemo(
    () => selectedIds.filter(id => visibleIds.has(id)),
    [selectedIds, visibleIds]
  );

  const refetchAll = useCallback(async () => {
    await Promise.all([refetchContacts(), refetchLists(), refetchUpcoming()]);
  }, [refetchContacts, refetchLists, refetchUpcoming]);

  const clearSelection = useCallback(() => setSelectedIds([]), []);

  const toggleSelected = useCallback((contactId: string) => {
    setSelectedIds(prev =>
      prev.includes(contactId) ? prev.filter(id => id !== contactId) : [...prev, contactId]
    );
  }, []);

  const toggleAll = useCallback(
    (selectAll: boolean) => setSelectedIds(selectAll ? visibleContacts.map(c => c.id) : []),
    [visibleContacts]
  );

  const openAddContact = () => {
    setPhoneError(null);
    setAddressErrors({});
    setContactDialog({
      id: null,
      draft: {
        name: '',
        email: '',
        relationship: '',
        phone: '',
        phoneCountry: DEFAULT_PHONE_COUNTRY,
        notes: '',
        address: emptyAddressDraft(),
      },
    });
  };

  const openEditContact = (contact: Contact) => {
    const { country, national } = fromE164(contact.phone);
    setPhoneError(null);
    setAddressErrors({});
    setContactDialog({
      id: contact.id,
      draft: {
        name: contact.name,
        email: contact.email ?? '',
        relationship: contact.relationship ?? '',
        phone: national,
        phoneCountry: country,
        notes: contact.notes ?? '',
        address: addressDraftFrom(contact),
      },
    });
  };

  const patchAddress = (patch: Partial<AddressDraft>) => {
    setAddressErrors({});
    setContactDialog(
      prev =>
        prev && { ...prev, draft: { ...prev.draft, address: { ...prev.draft.address, ...patch } } }
    );
  };

  const openAddOccasion = (contactId: string) =>
    setOccasionDialog({
      contactId,
      occasionId: null,
      draft: {
        kind: occasionKinds[0] ?? '',
        occursOn: '',
        recurring: true,
        reminderLeadDays: DEFAULT_REMINDER_LEAD_DAYS,
      },
    });

  const openEditOccasion = (contactId: string, occasion: Occasion) =>
    setOccasionDialog({
      contactId,
      occasionId: occasion.id,
      draft: {
        kind: occasion.kind,
        occursOn: occasion.occursOn,
        recurring: occasion.recurring,
        reminderLeadDays: occasion.reminderLeadDays,
      },
    });

  const handleSaveContact = async () => {
    if (!contactDialog) return;
    const { id, draft } = contactDialog;
    if (!draft.name.trim()) {
      toast.error('Please enter a name');
      return;
    }
    // An empty field clears the stored number; anything else has to parse to E.164.
    const typedPhone = draft.phone.trim();
    const phone = typedPhone ? toE164(typedPhone, draft.phoneCountry) : '';
    if (phone === null) {
      setPhoneError(INVALID_PHONE_MESSAGE);
      toast.error(INVALID_PHONE_MESSAGE);
      return;
    }
    setPhoneError(null);
    // The API rejects a partial address outright, so catch it here rather than letting the
    // user discover the rule from a server error.
    const addressProblems = validateAddress(draft.address);
    setAddressErrors(addressProblems);
    if (Object.keys(addressProblems).length > 0) {
      toast.error('Please finish the mailing address, or clear it');
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
          phone,
          notes: draft.notes.trim(),
          ...addressInput(draft.address),
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
      setSelectedIds(prev => prev.filter(id => id !== contact.id));
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
      // `reminderLeadDays` is always sent, so an explicit null reaches the API as
      // "reminders off" rather than reading as an omitted argument.
      const occasionFields = {
        kind: draft.kind,
        occursOn: draft.occursOn,
        recurring: draft.recurring,
        reminderLeadDays: draft.reminderLeadDays,
      };
      const variables = {
        input: occasionId ? { occasionId, ...occasionFields } : { contactId, ...occasionFields },
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

  // What the contacts panel says when it has nothing to show, which depends on why.
  const emptyMessage = () => {
    if (contacts.length === 0) return "You haven't added anyone yet.";
    if (activeList && listContacts.length === 0) return `No contacts on ${activeList.name} yet.`;
    if (addressFilter === 'has') return 'Nobody here has a mailing address yet.';
    if (addressFilter === 'missing') return 'Everyone here has a mailing address. Nice.';
    return 'No contacts match this filter.';
  };

  return (
    <div className="min-h-[calc(100vh-4rem)] bg-gradient-to-br from-purple-50 via-pink-50 to-blue-50 px-4 py-8">
      <Toaster />
      <div className="mx-auto w-full max-w-6xl">
        <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Contacts</h1>
            <p className="mt-1 text-gray-600">
              Keep track of the people you care about — their special days, and where to mail them a
              card.
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
            <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
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

        <div className="grid gap-6 lg:grid-cols-[16rem_1fr] lg:items-start">
          <ContactListSidebar
            lists={lists}
            selectedListId={selectedListId}
            onSelectList={listId => {
              setSelectedListId(listId);
              clearSelection();
            }}
            totalContacts={contacts.length}
            mailableContacts={mailableCount}
            onChanged={refetchAll}
          />

          <section className="min-w-0">
            <h2 className="mb-3 text-lg font-semibold text-gray-800">
              {activeList ? activeList.name : 'Contacts'}
            </h2>

            {contacts.length > 0 && (
              <ContactsToolbar
                selectedCount={effectiveSelectedIds.length}
                visibleCount={visibleContacts.length}
                onToggleAll={toggleAll}
                addressFilter={addressFilter}
                onAddressFilterChange={setAddressFilter}
                totalCount={listContacts.length}
                mailableCount={listMailableCount}
              />
            )}

            {effectiveSelectedIds.length > 0 && (
              <BulkActionBar
                selectedIds={effectiveSelectedIds}
                lists={lists}
                activeList={activeList}
                onClearSelection={clearSelection}
                onChanged={refetchAll}
              />
            )}

            {visibleContacts.length === 0 ? (
              <div className="rounded-lg border border-dashed border-gray-300 bg-white/60 p-8 text-center">
                <p className="text-gray-600">{emptyMessage()}</p>
                {contacts.length === 0 && (
                  <Button onClick={openAddContact} variant="outline" className="mt-4">
                    <UserPlus className="mr-2 h-4 w-4" />
                    Add your first contact
                  </Button>
                )}
              </div>
            ) : (
              <ul className="space-y-4">
                {visibleContacts.map(contact => (
                  <ContactRow
                    key={contact.id}
                    contact={contact}
                    selected={effectiveSelectedIds.includes(contact.id)}
                    onToggleSelected={toggleSelected}
                    onEdit={openEditContact}
                    onDelete={handleDeleteContact}
                    onAddOccasion={openAddOccasion}
                    onEditOccasion={openEditOccasion}
                    onDeleteOccasion={handleDeleteOccasion}
                  />
                ))}
              </ul>
            )}
          </section>
        </div>
      </div>

      {/* Contact add/edit dialog */}
      <Dialog open={!!contactDialog} onOpenChange={open => !open && setContactDialog(null)}>
        <DialogContent className="max-h-[90vh] overflow-y-auto">
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
              <div className="space-y-1.5">
                <Label htmlFor="contact-phone">Phone</Label>
                <PhoneInput
                  id="contact-phone"
                  country={contactDialog.draft.phoneCountry}
                  // Changing the country also re-formats the number, so these two setters
                  // fire back to back — they have to update from the latest state rather
                  // than from the snapshot this render closed over.
                  onCountryChange={country =>
                    setContactDialog(
                      prev => prev && { ...prev, draft: { ...prev.draft, phoneCountry: country } }
                    )
                  }
                  value={contactDialog.draft.phone}
                  onValueChange={value => {
                    setPhoneError(null);
                    setContactDialog(
                      prev => prev && { ...prev, draft: { ...prev.draft, phone: value } }
                    );
                  }}
                  onBlur={() => {
                    const typed = contactDialog.draft.phone.trim();
                    setPhoneError(
                      typed && !toE164(typed, contactDialog.draft.phoneCountry)
                        ? INVALID_PHONE_MESSAGE
                        : null
                    );
                  }}
                  invalid={!!phoneError}
                  placeholder="(415) 555-0123"
                />
                {phoneError && <p className="text-sm text-red-600">{phoneError}</p>}
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="contact-notes">Notes</Label>
                <Textarea
                  id="contact-notes"
                  value={contactDialog.draft.notes}
                  onChange={e =>
                    setContactDialog({
                      ...contactDialog,
                      draft: { ...contactDialog.draft, notes: e.target.value },
                    })
                  }
                  placeholder="Met at the Dec conference — lead client, follow up in Q3"
                  rows={3}
                />
              </div>
              <AddressFields
                value={contactDialog.draft.address}
                onChange={patchAddress}
                errors={addressErrors}
                defaultOpen={hasAddressInput(contactDialog.draft.address)}
              />
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
              <div className="space-y-1.5">
                <Label htmlFor="occasion-reminder">Remind me</Label>
                <Select
                  value={
                    occasionDialog.draft.reminderLeadDays === null
                      ? REMINDER_OFF
                      : String(occasionDialog.draft.reminderLeadDays)
                  }
                  onValueChange={value =>
                    setOccasionDialog({
                      ...occasionDialog,
                      draft: {
                        ...occasionDialog.draft,
                        reminderLeadDays: value === REMINDER_OFF ? null : Number(value),
                      },
                    })
                  }
                >
                  <SelectTrigger id="occasion-reminder">
                    <SelectValue placeholder="Pick a reminder" />
                  </SelectTrigger>
                  <SelectContent>
                    {reminderLeadOptions.map(days => (
                      <SelectItem key={days} value={String(days)}>
                        {reminderLeadLabel(days)}
                      </SelectItem>
                    ))}
                    <SelectItem value={REMINDER_OFF}>Don&apos;t remind me</SelectItem>
                  </SelectContent>
                </Select>
                <p className="text-xs text-gray-500">
                  We&apos;ll email you ahead of the day
                  {occasionDialog.draft.recurring ? ', every year' : ''}, so you have time to send a
                  card.
                </p>
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
