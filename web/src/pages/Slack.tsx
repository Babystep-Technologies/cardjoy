import React, { useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import * as motion from 'motion/react-client';
import Reveal from '@/components/Reveal';
import { slackInstallUrl, DEMO_VIDEO_URL } from '@/lib/slack';
import {
  Slack as SlackIcon,
  Zap,
  Users,
  Image as ImageIcon,
  ShieldCheck,
  Play,
} from 'lucide-react';

const AddToSlackButton: React.FC = () => (
  <a href={slackInstallUrl()} aria-label="Add CardJoy to Slack">
    <img
      alt="Add to Slack"
      height="48"
      width="167"
      className="h-12 w-auto"
      src="https://platform.slack-edge.com/img/add_to_slack.png"
      srcSet="https://platform.slack-edge.com/img/add_to_slack.png 1x, https://platform.slack-edge.com/img/add_to_slack@2x.png 2x"
    />
  </a>
);

const features = [
  {
    icon: Zap,
    title: 'Start a card without leaving Slack',
    description:
      'Run /cardjoy, pick a coworker and an occasion, and CardJoy creates the group card for you — no tab-switching, no copy-pasting links.',
  },
  {
    icon: Users,
    title: 'Everyone signs together',
    description:
      'Share the card in the channel so the whole team can add messages before it goes out. No chasing signatures across DMs.',
  },
  {
    icon: ImageIcon,
    title: 'Beautiful cards by default',
    description:
      'First day, farewell, promotion, or work anniversary — each occasion comes with a matching cover so the card looks great instantly.',
  },
  {
    icon: ShieldCheck,
    title: 'Minimal permissions',
    description:
      'CardJoy only asks for what the flow needs: the slash command and reading a user’s name to address the card. Nothing else.',
  },
];

const steps = [
  {
    label: 'Add to Slack',
    detail: 'Install CardJoy in your workspace with one click — any workspace admin can do it.',
  },
  {
    label: 'Run /cardjoy',
    detail: 'Choose who the card is for and the occasion. CardJoy sets up the card in seconds.',
  },
  {
    label: 'Sign and send',
    detail:
      'Coworkers add their messages and photos, then the finished card lands with the person.',
  },
];

const DemoSection: React.FC = () => (
  <section id="demo" className="bg-gray-50 py-24 px-4 scroll-mt-20">
    <div className="max-w-4xl mx-auto">
      <Reveal>
        <h2 className="text-gray-900 text-3xl md:text-5xl font-black text-center mb-4">
          See it in action
        </h2>
        <p className="text-gray-600 text-lg text-center mb-12 max-w-2xl mx-auto">
          Watch how a group card goes from <code className="font-mono">/cardjoy</code> to signed and
          sent — without anyone leaving Slack.
        </p>
      </Reveal>
      <Reveal>
        <div className="relative aspect-video w-full rounded-3xl overflow-hidden shadow-xl border border-gray-200 bg-gray-900">
          {DEMO_VIDEO_URL ? (
            <iframe
              className="absolute inset-0 w-full h-full"
              src={DEMO_VIDEO_URL}
              title="CardJoy for Slack demo"
              loading="lazy"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowFullScreen
            />
          ) : (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900 text-center px-4">
              <div className="flex items-center justify-center w-20 h-20 rounded-full bg-white/15 border border-white/30 backdrop-blur-sm mb-5">
                <Play className="w-9 h-9 text-white translate-x-0.5" />
              </div>
              <p className="text-white text-lg font-semibold">Demo coming soon</p>
              <p className="text-white/70 text-sm mt-1">
                We’re putting the finishing touches on it.
              </p>
            </div>
          )}
        </div>
      </Reveal>
    </div>
  </section>
);

const Slack: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    const previousTitle = document.title;
    document.title = 'CardJoy for Slack — group cards where your team already works';
    return () => {
      document.title = previousTitle;
    };
  }, []);

  // Scroll to a section when navigated with a hash (e.g. /slack#demo from the nav).
  // Deferred a beat so the scroll runs against the settled layout, not the mid-mount one.
  useEffect(() => {
    if (!location.hash) return;
    const timer = setTimeout(() => {
      document.querySelector(location.hash)?.scrollIntoView({ behavior: 'instant' });
    }, 100);
    return () => clearTimeout(timer);
  }, [location]);

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
              <SlackIcon className="w-4 h-4" />
              CardJoy for Slack
            </span>
            <h1 className="text-white text-4xl md:text-6xl font-black leading-tight mb-6">
              Group cards, right where your team already works
            </h1>
            <p className="text-white/80 text-lg md:text-2xl font-medium max-w-2xl mx-auto">
              Celebrate birthdays, farewells, promotions, and work anniversaries with a group card
              your whole team signs — all from a single <code className="font-mono">/cardjoy</code>{' '}
              command in Slack.
            </p>
          </div>
        </Reveal>

        <motion.div
          className="mt-10 relative z-10 flex flex-col sm:flex-row items-center gap-4"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.6 }}
        >
          <AddToSlackButton />
          <a
            href="#how-it-works"
            className="text-white/90 font-semibold underline-offset-4 hover:underline"
          >
            See how it works
          </a>
        </motion.div>
      </section>

      {/* Demo video */}
      <DemoSection />

      {/* Feature grid */}
      <section className="bg-white py-24 px-4">
        <div className="max-w-6xl mx-auto">
          <Reveal>
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black text-center mb-16">
              Everything you need to make someone’s day
            </h2>
          </Reveal>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {features.map(feature => (
              <Reveal key={feature.title}>
                <div className="h-full rounded-3xl border-2 border-gray-100 p-8 hover:shadow-xl transition-shadow">
                  <div
                    className="flex items-center justify-center w-12 h-12 rounded-xl mb-5"
                    style={{ backgroundColor: 'var(--color-brand-blue)' }}
                  >
                    <feature.icon className="w-6 h-6 text-white" />
                  </div>
                  <h3 className="text-gray-900 text-xl font-bold mb-2">{feature.title}</h3>
                  <p className="text-gray-600 leading-relaxed">{feature.description}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* How it works */}
      <section id="how-it-works" className="bg-gray-50 py-24 px-4 scroll-mt-20">
        <div className="max-w-5xl mx-auto">
          <Reveal>
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black text-center mb-16">
              Three steps from install to celebration
            </h2>
          </Reveal>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {steps.map((step, index) => (
              <Reveal key={step.label}>
                <div className="text-center">
                  <div
                    className="flex items-center justify-center w-14 h-14 rounded-full mx-auto mb-5 text-white text-xl font-black"
                    style={{ backgroundColor: 'var(--color-brand-pink)' }}
                  >
                    {index + 1}
                  </div>
                  <h3 className="text-gray-900 text-xl font-bold mb-2">{step.label}</h3>
                  <p className="text-gray-600 leading-relaxed">{step.detail}</p>
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
              Add CardJoy to your workspace
            </h2>
            <p className="text-white/90 text-lg md:text-2xl font-medium mb-10">
              Free to install. Start celebrating your team in the next minute.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <AddToSlackButton />
              <button
                onClick={() => navigate('/group-card/new')}
                className="bg-white/15 text-white border border-white/40 rounded-2xl px-9 py-5 font-bold text-lg hover:bg-white/25 hover:scale-105 transition-all backdrop-blur-sm w-full sm:w-auto"
              >
                Try a group card first
              </button>
            </div>
            <p className="text-white/70 text-sm mt-8">
              By installing you agree to our{' '}
              <a href="/terms" className="underline underline-offset-4">
                Terms
              </a>{' '}
              and{' '}
              <a href="/privacy" className="underline underline-offset-4">
                Privacy Policy
              </a>
              .
            </p>
          </div>
        </Reveal>
      </section>
    </div>
  );
};

export default Slack;
