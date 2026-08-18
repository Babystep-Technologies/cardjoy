// Date and label formatting shared by the Contacts page and its row component.

// Occasion dates are plain "YYYY-MM-DD" strings with no time or zone. Build the Date from the
// parts so it renders on the intended calendar day regardless of the viewer's timezone.
export function formatDate(iso: string): string {
  const [year, month, day] = iso.split('-').map(Number);
  return new Date(year, month - 1, day).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

export function daysUntil(iso: string): number {
  const [year, month, day] = iso.split('-').map(Number);
  const target = new Date(year, month - 1, day);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return Math.round((target.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
}

export function relativeLabel(iso: string): string {
  const days = daysUntil(iso);
  if (days <= 0) return 'Today';
  if (days === 1) return 'Tomorrow';
  return `in ${days} days`;
}

// Round lead times read better as weeks or months than as a day count.
export function reminderLeadLabel(days: number): string {
  if (days % 30 === 0) return days === 30 ? '1 month before' : `${days / 30} months before`;
  if (days % 7 === 0) return days === 7 ? '1 week before' : `${days / 7} weeks before`;
  return days === 1 ? '1 day before' : `${days} days before`;
}
