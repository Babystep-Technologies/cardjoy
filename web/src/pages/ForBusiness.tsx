import React, { useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import * as motion from 'motion/react-client';
import Reveal from '@/components/Reveal';
import { slackInstallUrl } from '@/lib/slack';
import {
  Slack,
  CalendarClock,
  Building2,
  Sparkles,
  ArrowRight,
  Mail,
  Users,
  Send,
} from 'lucide-react';

/**
 * The Business hub. CardJoy supports exactly two business use cases, and this page
 * exists to tell them apart:
 *
 *   1. Companies celebrating their own people — group cards started from Slack.
 *   2. Owners who live on client relationships — a contact book of client occasions
 *      that emails a reminder ahead of the date.
 *
 * Reminders belong to use case 2 only: the user adds the people and dates themselves.
 * Slack has no roster and remembers no dates, so nothing on this page may suggest that
 * installing the Slack app makes birthdays or work anniversaries surface on their own.
 */

// The two supported paths, rendered side by side so a visitor can self-select.
const paths = [
  {
    id: 'slack',
    icon: Slack,
    eyebrow: 'For teams',
    title: 'Group cards, started from Slack',
    summary:
      'Your team already celebrates each other. CardJoy gives them one command to do it without the DM thread and the passed-around doc.',
    points: [
      'Run /cardjoy in Slack, pick the person and the occasion.',
      'Share the card in the channel so everyone can sign it.',
      'Coworkers add messages and photos, then it goes to the person.',
    ],
    route: '/slack',
    cta: 'See CardJoy for Slack',
    gradient: 'from-[var(--color-brand-pink)] to-[var(--color-brand-blue)]',
  },
  {
    id: 'clients',
    icon: CalendarClock,
    eyebrow: 'For client relationships',
    title: 'Never forget a client’s occasion',
    summary:
      'If your business runs on relationships, remembering the date is the whole game. Add your clients once and CardJoy carries the calendar for you.',
    points: [
      'Add clients to your contact book with their birthdays and milestones.',
      'CardJoy emails you a week ahead, with a design already picked out.',
      'One click opens a pre-filled card you can schedule for the day itself.',
    ],
    route: '/client-occasions',
    cta: 'See how client occasions work',
    gradient: 'from-[var(--color-brand-green)] to-[var(--color-brand-yellow)]',
  },
];

// True of both paths. No team account, admin console, or automatic roster is claimed
// here, because none of those exist.
const shared = [
  {
    icon: Sparkles,
    title: 'Cards worth opening',
    description:
      'Animated covers, photos, GIFs, and messages from everyone — closer to a real card than an email with a signature block.',
  },
  {
    icon: Send,
    title: 'Nothing for the recipient to install',
    description:
      'Every card is a link. The person you are celebrating opens it in a browser, with no account and no app.',
  },
  {
    icon: Users,
    title: 'Start free, on your own',
    description:
      'Sign up and send without a sales call or a contract. CardJoy is open source, and you can try a card before committing to anything.',
  },
];

const ForBusiness: React.FC = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const previousTitle = document.title;
    document.title = 'CardJoy for Business — team cards in Slack & client occasions';
    return () => {
      document.title = previousTitle;
    };
  }, []);

  return (
    <div className="flex flex-col w-full overflow-x-hidden">
      {/* Hero */}
      <section className="bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900 min-h-[90vh] flex flex-col justify-center items-center px-4 py-[8vh] relative">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-[var(--color-brand-blue)]/20 rounded-full blur-3xl"></div>
          <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-[var(--color-brand-pink)]/20 rounded-full blur-3xl"></div>
        </div>

        <Reveal>
          <div className="max-w-3xl mx-auto text-center relative z-10">
            <span className="inline-flex items-center gap-2 text-white/80 text-sm font-semibold uppercase tracking-wide bg-white/10 border border-white/20 rounded-full px-4 py-1.5 mb-6">
              <Building2 className="w-4 h-4" />
              CardJoy for Business
            </span>
            <h1 className="text-white text-4xl md:text-6xl font-black leading-tight mb-6">
              The relationships your business runs on, remembered
            </h1>
            <p className="text-white/80 text-lg md:text-2xl font-medium max-w-2xl mx-auto">
              Two ways businesses use CardJoy: group cards your team signs in Slack, and a contact
              book that reminds you before a client’s big day.
            </p>
          </div>
        </Reveal>

        <motion.div
          className="mt-10 relative z-10 flex flex-col sm:flex-row items-center gap-4"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.6 }}
        >
          <button
            onClick={() => navigate('/sign_up')}
            className="group bg-white text-gray-900 rounded-2xl px-9 py-5 flex items-center justify-center gap-3 hover:scale-105 transition-all shadow-xl hover:shadow-2xl w-full sm:w-auto"
          >
            <span className="text-lg font-bold">Get started free</span>
            <ArrowRight className="w-5 h-5 group-hover:translate-x-0.5 transition-transform" />
          </button>
          <a
            href="#two-ways"
            className="text-white/90 font-semibold underline-offset-4 hover:underline"
          >
            See both use cases
          </a>
        </motion.div>
      </section>

      {/* The two paths — the heart of the page */}
      <section id="two-ways" className="bg-white py-24 px-4 scroll-mt-20">
        <div className="max-w-6xl mx-auto">
          <Reveal>
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black text-center mb-4">
              Which one sounds like you?
            </h2>
            <p className="text-gray-600 text-lg text-center max-w-2xl mx-auto mb-16">
              Plenty of businesses end up using both. Start wherever the next card is.
            </p>
          </Reveal>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {paths.map(path => (
              <Reveal key={path.id}>
                <div className="h-full flex flex-col rounded-3xl border-2 border-gray-100 p-8 md:p-10 hover:shadow-xl transition-shadow">
                  <div
                    className={`flex items-center justify-center w-14 h-14 rounded-2xl mb-6 bg-gradient-to-br ${path.gradient}`}
                  >
                    <path.icon className="w-7 h-7 text-white" />
                  </div>
                  <span className="text-xs font-bold uppercase tracking-wide text-gray-400 mb-2">
                    {path.eyebrow}
                  </span>
                  <h3 className="text-gray-900 text-2xl font-black mb-3">{path.title}</h3>
                  <p className="text-gray-600 leading-relaxed mb-6">{path.summary}</p>
                  <ul className="flex flex-col gap-3 mb-8">
                    {path.points.map(point => (
                      <li key={point} className="flex items-start gap-3 text-gray-700">
                        <span
                          aria-hidden="true"
                          className="mt-2 w-1.5 h-1.5 rounded-full shrink-0"
                          style={{ backgroundColor: 'var(--color-brand-pink)' }}
                        />
                        <span className="leading-relaxed">{point}</span>
                      </li>
                    ))}
                  </ul>
                  <Link
                    to={path.route}
                    className="group mt-auto inline-flex items-center gap-2 font-bold text-gray-900 underline-offset-4 hover:underline"
                  >
                    {path.cta}
                    <ArrowRight className="w-4 h-4 group-hover:translate-x-0.5 transition-transform" />
                  </Link>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* Honest framing of what remembers what */}
      <section className="bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50 py-24 px-4">
        <Reveal>
          <div className="max-w-4xl mx-auto text-center">
            <Mail className="w-10 h-10 mx-auto mb-6" style={{ color: 'var(--color-brand-pink)' }} />
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black mb-6">
              You add the people. CardJoy keeps the dates.
            </h2>
            <p className="text-gray-600 text-lg md:text-2xl font-medium max-w-3xl mx-auto">
              The Slack app makes a card in seconds when your team already knows an occasion is
              coming. The reminders come from your own contact book: add someone once, record the
              date, and CardJoy emails you a week before it comes around — so the card gets written
              while there is still time to send it.
            </p>
            <Link
              to="/client-occasions"
              className="group mt-8 inline-flex items-center gap-2 font-bold text-gray-900 underline-offset-4 hover:underline"
            >
              How reminders work
              <ArrowRight className="w-4 h-4 group-hover:translate-x-0.5 transition-transform" />
            </Link>
          </div>
        </Reveal>
      </section>

      {/* Shared value */}
      <section className="bg-white py-24 px-4">
        <div className="max-w-6xl mx-auto">
          <Reveal>
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black text-center mb-16">
              True either way you use it
            </h2>
          </Reveal>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {shared.map(item => (
              <Reveal key={item.title}>
                <div className="h-full rounded-3xl border-2 border-gray-100 p-8 hover:shadow-xl transition-shadow">
                  <div
                    className="flex items-center justify-center w-12 h-12 rounded-xl mb-5"
                    style={{ backgroundColor: 'var(--color-brand-blue)' }}
                  >
                    <item.icon className="w-6 h-6 text-white" />
                  </div>
                  <h3 className="text-gray-900 text-xl font-bold mb-2">{item.title}</h3>
                  <p className="text-gray-600 leading-relaxed">{item.description}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="bg-gradient-to-br from-purple-600 via-pink-500 to-blue-600 py-24 px-4">
        <Reveal>
          <div className="max-w-3xl mx-auto text-center">
            <h2 className="text-white text-3xl md:text-6xl font-black leading-tight mb-6">
              Make everyone feel remembered
            </h2>
            <p className="text-white/90 text-lg md:text-2xl font-medium mb-10">
              Start free today — with your team in Slack, or with the clients you never want to
              miss.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <button
                onClick={() => navigate('/sign_up')}
                className="bg-white text-gray-900 rounded-2xl px-9 py-5 font-bold text-lg hover:scale-105 transition-all shadow-xl hover:shadow-2xl w-full sm:w-auto"
              >
                Get started free
              </button>
              <a
                href={slackInstallUrl()}
                aria-label="Add CardJoy to Slack"
                className="bg-white/15 text-white border border-white/40 rounded-2xl px-9 py-5 font-bold text-lg hover:bg-white/25 hover:scale-105 transition-all backdrop-blur-sm w-full sm:w-auto text-center"
              >
                Add to Slack
              </a>
            </div>
          </div>
        </Reveal>
      </section>
    </div>
  );
};

export default ForBusiness;
