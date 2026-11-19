import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import * as motion from 'motion/react-client';
import { useFeatureFlagEnabled } from 'posthog-js/react';
import { OccasionMegaMenu } from './OccasionMegaMenu';
import { ProductMenu } from './ProductMenu';
import { BusinessMenu } from './BusinessMenu';
import { UserMenu } from './UserMenu';
import Wordmark from './Wordmark';
import { OrganizationMenu, MobileOrganizationSwitcher } from './OrganizationMenu';
import { IntentPickerDialog } from './IntentPickerDialog';
import {
  Accordion,
  AccordionItem,
  AccordionTrigger,
  AccordionContent,
} from '@/components/ui/accordion';
import { cardTypes } from '@/config/cardTypes';
import { businessLinks } from '@/config/businessLinks';
import { slackInstallUrl } from '@/lib/slack';
import { getInitials } from '@/lib/utils';

// Shared nav-link + CTA styling used across auth states and desktop/mobile.
const navLinkClass = 'text-gray-600 hover:text-gray-900 transition font-medium';
const primaryButtonClass =
  'bg-black text-white px-4 py-2 rounded-md font-semibold hover:bg-gray-800 transition';

const Header: React.FC = () => {
  const { user, loading, logout } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const isStaging = import.meta.env.VITE_ENV === 'staging';
  const isMaintenance = useFeatureFlagEnabled(import.meta.env.VITE_MAINTENANCE_MODE_FEATURE_FLAG);

  if (loading) return null;

  return (
    <motion.div
      animate={{ opacity: [0, 1], y: [-50, 0] }}
      transition={{ duration: 0.5 }}
      className="fixed top-0 left-0 w-full z-50"
    >
      {/* Staging banner */}
      {isStaging && (
        <div className="bg-yellow-100 text-yellow-800 text-sm font-medium text-center px-3 py-2 shadow-sm sm:text-base">
          <strong>test mode:</strong> data is temporary and may be reset periodically.
        </div>
      )}

      {/* Maintenance banner */}
      {isMaintenance && (
        <div className="bg-red-100 text-red-800 text-sm font-medium text-center px-3 py-2 shadow-sm sm:text-base">
          <strong>maintenance mode:</strong> features may be temporarily unavailable.
        </div>
      )}

      {/* Main header */}
      <div className="bg-white shadow-md">
        <div className="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-10 h-16 flex items-center justify-between">
          {/* Logo */}
          <motion.div
            whileHover={{ scale: 1.1 }}
            transition={{ type: 'spring', stiffness: 300, damping: 15 }}
            className="flex items-center"
          >
            <Link to="/" className="flex items-center group">
              <Wordmark className="h-[33px] w-auto" />
            </Link>
          </motion.div>

          {/* Desktop Nav */}
          <div className="hidden sm:flex items-center gap-6 text-base">
            {/* Shared marketing nav — identical across auth states */}
            <ProductMenu />
            <BusinessMenu />
            <OccasionMegaMenu />

            {/* Account cluster — the only part that swaps with auth state */}
            {user ? (
              <div className="flex items-center gap-4">
                <OrganizationMenu />
                <IntentPickerDialog>
                  <button type="button" className={primaryButtonClass}>
                    Create card
                  </button>
                </IntentPickerDialog>
                <UserMenu />
              </div>
            ) : (
              <div className="flex items-center gap-4">
                <Link to="/sign_in" className={navLinkClass}>
                  Sign In
                </Link>
                <Link to="/sign_up" className={primaryButtonClass}>
                  Sign Up Free
                </Link>
              </div>
            )}
          </div>

          {/* Mobile hamburger */}
          <button
            onClick={() => setMenuOpen(!menuOpen)}
            className="sm:hidden flex items-center justify-center w-10 h-10 text-2xl text-gray-700 rounded-md focus:outline-none focus:ring-2 focus:ring-gray-300"
            aria-label={menuOpen ? 'Close menu' : 'Open menu'}
          >
            <span aria-hidden="true">{menuOpen ? '✕' : '☰'}</span>
          </button>
        </div>

        {/* Mobile Dropdown */}
        {menuOpen && (
          <motion.div
            animate={{ opacity: [0, 1], height: ['0px', 'auto'] }}
            transition={{ duration: 0.3 }}
            className="sm:hidden w-full px-4 pb-4 bg-white shadow-inner overflow-hidden"
          >
            <div className="flex flex-col gap-3 mt-4 text-base">
              {/* Shared marketing nav — identical across auth states */}
              <Accordion type="single" collapsible className="w-full">
                <AccordionItem value="personal">
                  <AccordionTrigger className="text-gray-800">Personal</AccordionTrigger>
                  <AccordionContent>
                    <div className="flex flex-col gap-3 pl-2">
                      {cardTypes
                        .filter(type => type.route)
                        .map(type => (
                          <Link
                            key={type.id}
                            to={type.route}
                            onClick={() => setMenuOpen(false)}
                            className={navLinkClass}
                          >
                            {type.label}
                          </Link>
                        ))}
                    </div>
                  </AccordionContent>
                </AccordionItem>
                <AccordionItem value="business">
                  <AccordionTrigger className="text-gray-800">Business</AccordionTrigger>
                  <AccordionContent>
                    <div className="flex flex-col gap-3 pl-2">
                      {businessLinks.map(link => (
                        <Link
                          key={link.id}
                          to={link.route}
                          onClick={() => setMenuOpen(false)}
                          className={navLinkClass}
                        >
                          {link.label}
                        </Link>
                      ))}
                      <a
                        href={slackInstallUrl()}
                        className="mt-1"
                        aria-label="Add Felicito to Slack"
                      >
                        <img
                          alt="Add to Slack"
                          height="40"
                          width="139"
                          src="https://platform.slack-edge.com/img/add_to_slack.png"
                          srcSet="https://platform.slack-edge.com/img/add_to_slack.png 1x, https://platform.slack-edge.com/img/add_to_slack@2x.png 2x"
                        />
                      </a>
                    </div>
                  </AccordionContent>
                </AccordionItem>
              </Accordion>
              <Link
                to="/occasions"
                onClick={() => setMenuOpen(false)}
                className={`${navLinkClass} text-center`}
              >
                Occasions
              </Link>

              <hr className="my-1" />

              {/* Account section — the only part that swaps with auth state */}
              {user ? (
                <>
                  <div className="flex items-center gap-3 px-1 py-1">
                    <span
                      aria-hidden="true"
                      className="flex h-9 w-9 items-center justify-center rounded-full bg-black text-sm font-semibold text-white"
                    >
                      {getInitials(user.name, user.email)}
                    </span>
                    <div className="min-w-0">
                      <p className="truncate font-semibold text-gray-900">
                        {user.name || 'Your account'}
                      </p>
                      {user.email && <p className="truncate text-xs text-gray-500">{user.email}</p>}
                    </div>
                  </div>
                  <IntentPickerDialog>
                    <button type="button" className={`${primaryButtonClass} text-center`}>
                      Create card
                    </button>
                  </IntentPickerDialog>
                  <Link
                    to="/dashboard"
                    onClick={() => setMenuOpen(false)}
                    className={`${navLinkClass} text-center`}
                  >
                    Dashboard
                  </Link>
                  <Link
                    to="/contacts"
                    onClick={() => setMenuOpen(false)}
                    className={`${navLinkClass} text-center`}
                  >
                    Contacts
                  </Link>
                  <Link
                    to="/profile"
                    onClick={() => setMenuOpen(false)}
                    className={`${navLinkClass} text-center`}
                  >
                    Profile
                  </Link>

                  <hr className="my-1" />
                  <MobileOrganizationSwitcher onNavigate={() => setMenuOpen(false)} />
                  <hr className="my-1" />

                  <button
                    type="button"
                    onClick={() => {
                      setMenuOpen(false);
                      logout();
                    }}
                    className="text-red-600 hover:text-red-700 font-medium text-center transition"
                  >
                    Sign Out
                  </button>
                </>
              ) : (
                <>
                  <Link
                    to="/sign_in"
                    onClick={() => setMenuOpen(false)}
                    className={`${navLinkClass} text-center`}
                  >
                    Sign In
                  </Link>
                  <Link
                    to="/sign_up"
                    onClick={() => setMenuOpen(false)}
                    className={`${primaryButtonClass} text-center`}
                  >
                    Sign Up Free
                  </Link>
                </>
              )}
            </div>
          </motion.div>
        )}
      </div>
    </motion.div>
  );
};

export default Header;
