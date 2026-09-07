import React from 'react';
import { matchPath, useLocation } from 'react-router-dom';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import { cn } from '@/lib/utils';

/**
 * The header is `fixed`, so it takes up no space in the flow and every page has
 * to reserve its height by hand. That height is `h-16` (64px) in Header.tsx,
 * plus the ~40px staging banner when that is showing.
 */
const HEADER_OFFSET = 'pt-16';
const HEADER_OFFSET_STAGING = 'pt-[104px]';

/**
 * Routes that own the whole viewport. These pages fill the space under the
 * header and scroll their own panes internally, so the marketing footer has
 * nowhere to go except below the fold — where it turns every stray wheel
 * gesture into a page scroll and drags the surface out from under the pointer.
 *
 * Matched on the path rather than signalled up from the page, because a page
 * can only ask for this after the layout has already painted a scrollbar.
 */
const FULL_BLEED_ROUTES = ['/holiday-card/:externalId/edit'];

type Props = {
  children: React.ReactNode;
};

const RootLayout: React.FC<Props> = ({ children }) => {
  const isStaging = import.meta.env.VITE_ENV === 'staging';
  const { pathname } = useLocation();
  const fullBleed = FULL_BLEED_ROUTES.some(pattern => matchPath(pattern, pathname));

  return (
    <div
      className={cn(
        'antialiased flex flex-col',
        fullBleed ? 'h-screen overflow-hidden' : 'min-h-screen'
      )}
      style={{
        fontFamily: "'Montserrat', sans-serif",
      }}
    >
      <Header />
      {/*
        `min-h-0` lets a full-bleed page shrink to the space that is actually
        left instead of growing to fit its own content — without it a flex item
        never goes below its content height, which is the whole thing we are
        trying to prevent.
      */}
      <main
        className={cn(
          'flex-grow',
          isStaging ? HEADER_OFFSET_STAGING : HEADER_OFFSET,
          fullBleed && 'min-h-0'
        )}
      >
        {children}
      </main>
      {!fullBleed && <Footer />}
    </div>
  );
};

export default RootLayout;
