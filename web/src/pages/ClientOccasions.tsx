import React, { useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import * as motion from 'motion/react-client';
import Reveal from '@/components/Reveal';
import { useAuth } from '@/contexts/AuthContext';
import { CalendarClock, UserPlus, Mail, Send, NotebookPen, Repeat, ArrowRight } from 'lucide-react';

/**
 * Marketing page for CardJoy's second business use case: an owner whose business runs
 * on client relationships keeps their clients' occasions here so a card never gets
 * missed. Public on purpose — the feature itself lives behind auth at `/contacts`, so
 * without this page a prospect has no way to discover it.
 *
 * Every claim below maps to shipped behaviour: `Contact` (name, email, phone,
 * relationship, notes), `Occasion` (kind, date, recurring), `OccasionReminderJob`
 * (daily, `REMINDER_LEAD_DAYS = 7`, idempotent per occurrence) and
 * `OccasionReminderMailer` (design suggestion + deep link into the pre-filled 1-on-1
 * create flow with `deliverAt` set to the occasion's date). Do not add capabilities
 * here that the occasion book does not have.
 */

const steps = [
  {
    icon: UserPlus,
    label: 'Add your clients',
    detail:
      'Name, email, phone, how you know them, and any notes worth remembering before you write the next card.',
  },
  {
    icon: CalendarClock,
    label: 'Record their occasions',
    detail:
      'Birthdays, anniversaries, a closing date, a new job — mark the ones that come around every year and CardJoy rolls them forward on its own.',
  },
  {
    icon: Mail,
    label: 'Get the nudge a week out',
    detail:
      'CardJoy emails you seven days before the date, names the client and the occasion, and suggests a design to match.',
  },
  {
    icon: Send,
    label: 'Send in about a minute',
    detail:
      'The email links straight into a card with the recipient, occasion, and design already filled in — write your note and schedule it to land on the day.',
  },
];

const details = [
  {
    icon: Repeat,
    title: 'Annual dates roll forward',
    description:
      'Mark a birthday or work anniversary as recurring once. CardJoy tracks the next occurrence every year after that, and never reminds you twice for the same one.',
  },
  {
    icon: NotebookPen,
    title: 'Notes that make the card personal',
    description:
      'Keep the details that turn a generic greeting into something they remember — the dog’s name, the house they just bought, the daughter starting college.',
  },
  {
    icon: CalendarClock,
    title: 'See what is coming up',
    description:
      'Your contact book lists the occasions on the horizon, so you can look ahead instead of waiting to be told.',
  },
];

const ClientOccasions: React.FC = () => {
  const navigate = useNavigate();
  const { user } = useAuth();

  useEffect(() => {
    const previousTitle = document.title;
    document.title = 'Client occasions — never forget a client’s birthday | CardJoy';
    return () => {
      document.title = previousTitle;
    };
  }, []);

  // Signed-in visitors already have the feature; send them to it rather than to sign-up.
  const primaryCta = user
    ? { label: 'Open your contact book', route: '/contacts' }
    : { label: 'Get started free', route: '/sign_up' };

  return (
    <div className="flex flex-col w-full overflow-x-hidden">
      {/* Hero */}
      <section className="bg-gradient-to-br from-gray-900 via-emerald-900 to-gray-900 min-h-[90vh] flex flex-col justify-center items-center px-4 py-[8vh] relative">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-1/4 right-1/4 w-96 h-96 bg-[var(--color-brand-green)]/20 rounded-full blur-3xl"></div>
          <div className="absolute bottom-1/4 left-1/4 w-96 h-96 bg-[var(--color-brand-yellow)]/20 rounded-full blur-3xl"></div>
        </div>

        <Reveal>
          <div className="max-w-3xl mx-auto text-center relative z-10">
            <span className="inline-flex items-center gap-2 text-white/80 text-sm font-semibold uppercase tracking-wide bg-white/10 border border-white/20 rounded-full px-4 py-1.5 mb-6">
              <CalendarClock className="w-4 h-4" />
              Client occasions
            </span>
            <h1 className="text-white text-4xl md:text-6xl font-black leading-tight mb-6">
              Never forget a client’s big day again
            </h1>
            <p className="text-white/80 text-lg md:text-2xl font-medium max-w-2xl mx-auto">
              Add the clients you care about keeping, record their birthdays and milestones, and
              CardJoy emails you a week ahead — with the card already half-written.
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
            onClick={() => navigate(primaryCta.route)}
            className="group bg-white text-gray-900 rounded-2xl px-9 py-5 flex items-center justify-center gap-3 hover:scale-105 transition-all shadow-xl hover:shadow-2xl w-full sm:w-auto"
          >
            <span className="text-lg font-bold">{primaryCta.label}</span>
            <ArrowRight className="w-5 h-5 group-hover:translate-x-0.5 transition-transform" />
          </button>
          <a
            href="#how-it-works"
            className="text-white/90 font-semibold underline-offset-4 hover:underline"
          >
            See how it works
          </a>
        </motion.div>
      </section>

      {/* The problem */}
      <section className="bg-gradient-to-br from-yellow-50 via-green-50 to-blue-50 py-24 px-4">
        <Reveal>
          <div className="max-w-4xl mx-auto text-center">
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black mb-6">
              You meant to send something
            </h2>
            <p className="text-gray-600 text-lg md:text-2xl font-medium max-w-3xl mx-auto">
              Realtors, stylists, advisors, dentists, consultants — the work is repeat business, and
              repeat business is a relationship. Everyone intends to send the birthday card. It
              slips because nothing reminds you until you see the date go by. CardJoy is the thing
              that reminds you, early enough to actually do something about it.
            </p>
          </div>
        </Reveal>
      </section>

      {/* How it works */}
      <section id="how-it-works" className="bg-white py-24 px-4 scroll-mt-20">
        <div className="max-w-6xl mx-auto">
          <Reveal>
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black text-center mb-16">
              Set it up once, then just answer the email
            </h2>
          </Reveal>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {steps.map((step, index) => (
              <Reveal key={step.label}>
                <div className="h-full rounded-3xl border-2 border-gray-100 p-8 hover:shadow-xl transition-shadow">
                  <div className="flex items-center gap-3 mb-5">
                    <div
                      className="flex items-center justify-center w-12 h-12 rounded-xl"
                      style={{ backgroundColor: 'var(--color-brand-green)' }}
                    >
                      <step.icon className="w-6 h-6 text-white" />
                    </div>
                    <span className="text-3xl font-black text-gray-200">{index + 1}</span>
                  </div>
                  <h3 className="text-gray-900 text-xl font-bold mb-2">{step.label}</h3>
                  <p className="text-gray-600 leading-relaxed">{step.detail}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* What the reminder actually does */}
      <section className="bg-gray-50 py-24 px-4">
        <div className="max-w-5xl mx-auto">
          <Reveal>
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black text-center mb-6">
              The reminder does most of the work
            </h2>
            <p className="text-gray-600 text-lg text-center max-w-3xl mx-auto mb-14">
              It is not a calendar alert that leaves you staring at a blank page. The email arrives
              seven days out and carries everything the card needs.
            </p>
          </Reveal>
          <Reveal>
            <div className="rounded-3xl border-2 border-gray-200 bg-white p-8 md:p-12">
              <ul className="flex flex-col gap-5">
                {[
                  'Who it is for and which occasion is coming up.',
                  'A design suggestion chosen to fit the occasion.',
                  'A link that opens the card with the recipient, occasion, and design pre-filled.',
                  'A send date already set to the day itself, so you can write it now and forget it.',
                ].map(item => (
                  <li key={item} className="flex items-start gap-4 text-gray-700 text-lg">
                    <span
                      aria-hidden="true"
                      className="mt-2.5 w-2 h-2 rounded-full shrink-0"
                      style={{ backgroundColor: 'var(--color-brand-green)' }}
                    />
                    <span className="leading-relaxed">{item}</span>
                  </li>
                ))}
              </ul>
              <p className="text-gray-500 text-sm mt-8 leading-relaxed">
                Everything is pre-filled, and everything stays editable — change the design, the
                message, or the send date before it goes out.
              </p>
            </div>
          </Reveal>
        </div>
      </section>

      {/* Details */}
      <section className="bg-white py-24 px-4">
        <div className="max-w-6xl mx-auto">
          <Reveal>
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black text-center mb-16">
              Built for a book of clients you keep for years
            </h2>
          </Reveal>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {details.map(detail => (
              <Reveal key={detail.title}>
                <div className="h-full rounded-3xl border-2 border-gray-100 p-8 hover:shadow-xl transition-shadow">
                  <div
                    className="flex items-center justify-center w-12 h-12 rounded-xl mb-5"
                    style={{ backgroundColor: 'var(--color-brand-blue)' }}
                  >
                    <detail.icon className="w-6 h-6 text-white" />
                  </div>
                  <h3 className="text-gray-900 text-xl font-bold mb-2">{detail.title}</h3>
                  <p className="text-gray-600 leading-relaxed">{detail.description}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="bg-gradient-to-br from-emerald-600 via-teal-500 to-blue-600 py-24 px-4">
        <Reveal>
          <div className="max-w-3xl mx-auto text-center">
            <h2 className="text-white text-3xl md:text-6xl font-black leading-tight mb-6">
              Be the one who remembered
            </h2>
            <p className="text-white/90 text-lg md:text-2xl font-medium mb-10">
              Add your first few clients today. The next birthday will find you instead of the other
              way around.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <button
                onClick={() => navigate(primaryCta.route)}
                className="bg-white text-gray-900 rounded-2xl px-9 py-5 font-bold text-lg hover:scale-105 transition-all shadow-xl hover:shadow-2xl w-full sm:w-auto"
              >
                {primaryCta.label}
              </button>
              <Link
                to="/for-business"
                className="bg-white/15 text-white border border-white/40 rounded-2xl px-9 py-5 font-bold text-lg hover:bg-white/25 hover:scale-105 transition-all backdrop-blur-sm w-full sm:w-auto text-center"
              >
                CardJoy for Business
              </Link>
            </div>
          </div>
        </Reveal>
      </section>
    </div>
  );
};

export default ClientOccasions;
