import { Suspense, lazy, useState } from 'react';
import { LifeBuoy } from 'lucide-react';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';

// Everything past the button — FAQ text, the ticket mutation, NewTicketDialog — is only
// fetched once a visitor actually opens the panel, so the always-mounted launcher itself
// stays cheap enough to render in RootLayout on every page, signed in or not.
const SupportWidgetPanel = lazy(() => import('./components/SupportWidgetPanel'));

/** Global support entry point (#213): a bottom-right launcher available on every page,
 * replacing the old "Contact Us" link buried in Profile.tsx. */
export default function SupportWidget() {
  const [open, setOpen] = useState(false);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <button
          type="button"
          aria-label="Support"
          className="fixed bottom-5 right-5 z-40 flex h-14 w-14 items-center justify-center rounded-full bg-black text-white shadow-lg transition hover:bg-gray-800"
        >
          <LifeBuoy className="w-6 h-6" />
        </button>
      </PopoverTrigger>
      <PopoverContent
        side="top"
        align="end"
        sideOffset={12}
        className="w-80 max-h-[70vh] overflow-y-auto"
      >
        {open && (
          <Suspense fallback={<p className="text-sm text-gray-500 py-4 text-center">Loading…</p>}>
            <SupportWidgetPanel onNavigate={() => setOpen(false)} />
          </Suspense>
        )}
      </PopoverContent>
    </Popover>
  );
}
