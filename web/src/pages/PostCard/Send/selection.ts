/**
 * Resolving a `Selection` into the actual set of recipients (#151).
 *
 * The picker stores *what the user chose* — some lists, some individuals, some
 * individuals struck off — rather than the flat set of ids that fell out of
 * those choices at the moment they made them. That is the whole reason a list
 * selection "stays live": the members are read from the contacts on every
 * render, so somebody added to a chosen list tomorrow is in tomorrow's send.
 *
 * Storing the resolved ids instead would freeze the list at pick time and quietly
 * disagree with the Contacts page, which is exactly the surprise this flow is
 * meant not to spring on someone spending money.
 */
import type { Selection, SendContact } from './types';

/** Is this contact vouched for by one of the selected lists? */
function onSelectedList(contact: SendContact, listIds: string[]): boolean {
  if (listIds.length === 0) return false;
  return contact.contactLists.some(list => listIds.includes(list.id));
}

/**
 * Who is actually selected: everyone on a selected list, plus everyone ticked
 * individually, minus everyone explicitly struck off. Returned in the order the
 * contacts were given (alphabetical, from `myContacts`) so the recipient table
 * and the price table read the same way.
 */
export function resolveSelection(contacts: SendContact[], selection: Selection): SendContact[] {
  const excluded = new Set(selection.excludedContactIds);
  const included = new Set(selection.contactIds);

  return contacts.filter(
    contact =>
      !excluded.has(contact.id) &&
      (included.has(contact.id) || onSelectedList(contact, selection.listIds))
  );
}

export function isSelected(contact: SendContact, selection: Selection): boolean {
  if (selection.excludedContactIds.includes(contact.id)) return false;
  return selection.contactIds.includes(contact.id) || onSelectedList(contact, selection.listIds);
}

/**
 * Tick or untick one contact.
 *
 * Unticking someone a selected list vouches for records an exclusion rather
 * than dropping the list — the user meant "not this person", and dropping the
 * list would silently unselect everyone else on it.
 */
export function toggleContact(contact: SendContact, selection: Selection): Selection {
  if (isSelected(contact, selection)) {
    return {
      ...selection,
      contactIds: selection.contactIds.filter(id => id !== contact.id),
      excludedContactIds: onSelectedList(contact, selection.listIds)
        ? [...selection.excludedContactIds, contact.id]
        : selection.excludedContactIds,
    };
  }

  // Selecting clears any exclusion first, so a list member struck off and put
  // back does not need the id in both halves to cancel out.
  const excludedContactIds = selection.excludedContactIds.filter(id => id !== contact.id);
  const coveredByList = onSelectedList(contact, selection.listIds);

  return {
    ...selection,
    excludedContactIds,
    contactIds: coveredByList ? selection.contactIds : [...selection.contactIds, contact.id],
  };
}

/**
 * Tick or untick a whole list.
 *
 * Unticking drops the list *and* the exclusions that only existed to carve
 * holes in it, so re-selecting it later starts from the list as it stands
 * rather than from someone's forgotten edit two stages ago.
 */
export function toggleList(
  listId: string,
  selection: Selection,
  contacts: SendContact[]
): Selection {
  if (selection.listIds.includes(listId)) {
    const remainingLists = selection.listIds.filter(id => id !== listId);
    const stillCovered = new Set(
      contacts.filter(contact => onSelectedList(contact, remainingLists)).map(contact => contact.id)
    );

    return {
      listIds: remainingLists,
      contactIds: selection.contactIds,
      excludedContactIds: selection.excludedContactIds.filter(id => stillCovered.has(id)),
    };
  }

  const members = new Set(
    contacts.filter(contact => contact.contactLists.some(l => l.id === listId)).map(c => c.id)
  );

  return {
    listIds: [...selection.listIds, listId],
    contactIds: selection.contactIds,
    // Adding a list is an affirmative "these people": it undoes exclusions of
    // its own members rather than adding a list whose members are struck off.
    excludedContactIds: selection.excludedContactIds.filter(id => !members.has(id)),
  };
}

/** Drop ids that no longer name a contact — a contact deleted in another tab. */
export function pruneSelection(selection: Selection, contacts: SendContact[]): Selection {
  const known = new Set(contacts.map(contact => contact.id));
  const contactIds = selection.contactIds.filter(id => known.has(id));
  const excludedContactIds = selection.excludedContactIds.filter(id => known.has(id));

  if (
    contactIds.length === selection.contactIds.length &&
    excludedContactIds.length === selection.excludedContactIds.length
  ) {
    return selection;
  }
  return { ...selection, contactIds, excludedContactIds };
}
