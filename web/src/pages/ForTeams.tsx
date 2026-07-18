import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import * as motion from 'motion/react-client';
import Reveal from '@/components/Reveal';
import {
  Slack,
  CalendarClock,
  Wallet,
  ShieldCheck,
  Users,
  Sparkles,
  ArrowRight,
} from 'lucide-react';

const teamFeatures = [
  {
    icon: CalendarClock,
    title: 'Never miss a moment',
    description:
      'Birthdays, work anniversaries, farewells, and new-hire welcomes — CardJoy reminds the team and starts the card so no one has to remember.',
  },
  {
    icon: Slack,
    title: 'Right inside Slack',
    description:
      'Run /cardjoy where your team already works. Collect signatures and photos without chasing anyone across email threads.',
  },
  {
    icon: Wallet,
    title: 'One bill, not a group chat',
    description:
      'Stop passing the hat for $5 a person. Cover celebrations from a single team account with no reimbursements to sort out.',
  },
  {
    icon: ShieldCheck,
    title: 'Admin control',
    description:
      'Keep a consistent, on-brand celebration experience across every team, with the visibility to make sure no one is missed.',
  },
];

const steps = [
  {
    label: 'Connect your team',
    detail: 'Add CardJoy to Slack and bring in the people you celebrate.',
  },
  {
    label: 'We handle the timing',
    detail: 'CardJoy nudges the team ahead of every birthday and milestone.',
  },
  {
    label: 'Everyone signs, you send',
    detail: 'Coworkers add messages and photos; the card lands right on the day.',
  },
];

const ForTeams: React.FC = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const previousTitle = document.title;
    document.title = 'CardJoy for Teams — celebrate your whole company';
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
              <Users className="w-4 h-4" />
              CardJoy for Teams
            </span>
            <h1 className="text-white text-4xl md:text-6xl font-black leading-tight mb-6">
              Celebrate your whole team, without the group-chat chaos
            </h1>
            <p className="text-white/80 text-lg md:text-2xl font-medium max-w-2xl mx-auto">
              The same group cards people love — running automatically for every birthday, work
              anniversary, and farewell across your company.
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
            href="#how-it-works"
            className="text-white/90 font-semibold underline-offset-4 hover:underline"
          >
            See how it works
          </a>
        </motion.div>
      </section>

      {/* Bridge: same activity, two altitudes */}
      <section className="bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50 py-24 px-4">
        <Reveal>
          <div className="max-w-4xl mx-auto text-center">
            <Sparkles
              className="w-10 h-10 mx-auto mb-6"
              style={{ color: 'var(--color-brand-pink)' }}
            />
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black mb-6">
              What one coworker does by hand, CardJoy does for everyone
            </h2>
            <p className="text-gray-600 text-lg md:text-2xl font-medium max-w-3xl mx-auto">
              When someone organizes a birthday card, they chase signatures, collect cash, and hope
              they didn&apos;t forget anyone. Scale that to a whole company and it falls apart.
              CardJoy for Teams runs it for you — every person, every milestone, every time.
            </p>
          </div>
        </Reveal>
      </section>

      {/* Feature grid */}
      <section className="bg-white py-24 px-4">
        <div className="max-w-6xl mx-auto">
          <Reveal>
            <h2 className="text-gray-900 text-3xl md:text-5xl font-black text-center mb-16">
              Built for the people who make work feel human
            </h2>
          </Reveal>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {teamFeatures.map(feature => (
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
              Set it up once, then let it run
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
              Make everyone feel remembered
            </h2>
            <p className="text-white/90 text-lg md:text-2xl font-medium mb-10">
              Start free today. Bring your team along whenever you&apos;re ready.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <button
                onClick={() => navigate('/sign_up')}
                className="bg-white text-gray-900 rounded-2xl px-9 py-5 font-bold text-lg hover:scale-105 transition-all shadow-xl hover:shadow-2xl w-full sm:w-auto"
              >
                Get started free
              </button>
              <button
                onClick={() => navigate('/group-card/new')}
                className="bg-white/15 text-white border border-white/40 rounded-2xl px-9 py-5 font-bold text-lg hover:bg-white/25 hover:scale-105 transition-all backdrop-blur-sm w-full sm:w-auto"
              >
                Try a group card first
              </button>
            </div>
          </div>
        </Reveal>
      </section>
    </div>
  );
};

export default ForTeams;
