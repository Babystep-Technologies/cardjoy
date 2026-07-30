import React, { useEffect, useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { WordRotate } from '@/components/magicui/word-rotate';
import * as motion from 'motion/react-client';
import Reveal from '@/components/Reveal';
import Faq from '@/pages/Home/Faq';
import {
  Github,
  Star,
  Check,
  CalendarCheck,
  QrCode,
  Users,
  Sparkles,
  Heart,
  Send,
  ChevronLeft,
  ChevronRight,
  Building2,
  ArrowRight,
} from 'lucide-react';
import { occasions } from '@/config/occasions';
import { cardTypes, type CardTypeId } from '@/config/cardTypes';
import { GITHUB_REPO_URL } from '@/lib/constants';
import { IntentPickerDialog } from '@/components/IntentPickerDialog';
import { useAuth } from '@/contexts/AuthContext';

const cardFeatures = [
  { icon: Users, text: 'No signup needed for contributors' },
  { icon: Sparkles, text: 'Works for any occasion' },
  { icon: QrCode, text: 'QR code for in-person events' },
];

const oneOnOneFeatures = [
  { icon: Heart, text: 'One heartfelt message, just for them' },
  { icon: Sparkles, text: 'Opens with a celebratory effect' },
  { icon: Send, text: 'Share by link or send by email' },
];

const invitationFeatures = [
  { icon: Sparkles, text: 'Animated opening screen' },
  { icon: Check, text: 'Built-in RSVP tracking' },
  { icon: CalendarCheck, text: 'One-tap add to calendar' },
];

const holidayFeatures = [
  { icon: Sparkles, text: 'Festive seasonal designs' },
  { icon: Heart, text: 'Warm wishes for the whole list' },
  { icon: Send, text: 'Share by link or send by email' },
];

const featuresByType: Record<CardTypeId, { icon: typeof Users; text: string }[]> = {
  group: cardFeatures,
  one_on_one: oneOnOneFeatures,
  invitation: invitationFeatures,
  holiday: holidayFeatures,
};

const Home: React.FC = () => {
  const navigate = useNavigate();
  const { user } = useAuth();

  // Only dangle "for free" at signed-out visitors; it reads oddly once they have an account.
  const createCtaLabel = user ? 'Create a card' : 'Create a card for free';

  // Card-type showcase slideshow: emphasise one type at a time, themed in its brand color.
  const [activeSlide, setActiveSlide] = useState(0);
  const goToSlide = (index: number) =>
    setActiveSlide((index + cardTypes.length) % cardTypes.length);

  useEffect(() => {
    const timer = setInterval(() => {
      setActiveSlide(current => (current + 1) % cardTypes.length);
    }, 6000);
    return () => clearInterval(timer);
  }, [activeSlide]);

  const activeType = cardTypes[activeSlide];
  const activeFeatures = featuresByType[activeType.id];

  return (
    <div className="flex flex-col w-full overflow-x-hidden overscroll-y-auto">
      {/* Hero section */}
      <section className="scroll-section bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900 min-h-screen overflow-y-hidden flex flex-col justify-center items-center px-4 py-[5vh] relative">
        {/* Subtle gradient orbs for depth */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-purple-600/20 rounded-full blur-3xl"></div>
          <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-pink-600/20 rounded-full blur-3xl"></div>
          <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-blue-600/10 rounded-full blur-3xl"></div>
        </div>

        <Reveal>
          <h1 className="text-white text-4xl md:text-6xl font-bold text-center px-6 relative z-10">
            Make Life Moments Shine
            <WordRotate
              className="text-4xl md:text-6xl font-bold text-center px-6"
              words={[
                'Get Everyone to Sign One Card',
                'Send Someone a Heartfelt Note',
                'Invite Everyone to Celebrate',
                'Send Holiday Cheer to Your List',
              ]}
              colors={[
                'text-[var(--color-brand-pink)]',
                'text-[var(--color-brand-blue)]',
                'text-[var(--color-brand-green)]',
                'text-[var(--color-brand-yellow)]',
              ]}
            />
          </h1>

          <p className="text-white/80 text-lg md:text-2xl font-medium text-center px-6 mt-6 relative z-10 max-w-2xl mx-auto">
            Beautiful digital cards that make life&apos;s occasions memorable.
          </p>
        </Reveal>

        <motion.div
          className="mt-8 sm:mt-12 relative z-10 mx-4 flex flex-col items-center gap-5"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.6 }}
        >
          <IntentPickerDialog>
            <button className="group bg-white text-gray-900 rounded-2xl px-10 py-5 flex items-center justify-center gap-3 hover:scale-105 transition-all shadow-xl hover:shadow-2xl w-full sm:w-auto">
              <Sparkles className="w-5 h-5" />
              <span className="text-lg font-bold">{createCtaLabel}</span>
            </button>
          </IntentPickerDialog>
        </motion.div>
      </section>

      {/* Three-products showcase */}
      <section className="scroll-section bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50 min-h-screen overflow-y-hidden flex flex-col justify-center items-center py-[5vh] px-4 text-center">
        <Reveal>
          <h2 className="text-gray-900 text-4xl md:text-6xl pt-12 font-black mb-4">
            What do you want to do?
          </h2>
          <p className="text-gray-600 text-lg md:text-2xl font-medium mb-12">
            Start with the moment you have in mind — we'll pick the right card for it
          </p>
        </Reveal>

        <Reveal>
          <div className="relative w-full max-w-5xl mx-auto mb-8">
            {/* Slide — re-keyed per type so it re-triggers the fade on change */}
            <div
              key={activeType.id}
              className="animate-fade-in grid md:grid-cols-2 rounded-3xl bg-white shadow-2xl overflow-hidden text-left"
            >
              {/* Themed visual side, emphasising the type's brand color */}
              <div
                className={`bg-gradient-to-br ${activeType.gradient} p-10 sm:p-14 text-white flex flex-col justify-center min-h-[300px] sm:min-h-[360px]`}
              >
                {activeType.comingSoon && (
                  <span className="self-start mb-4 text-xs font-semibold uppercase tracking-wide bg-white/20 rounded-full px-3 py-1">
                    Coming soon
                  </span>
                )}
                <activeType.icon className="w-16 h-16 drop-shadow-lg mb-6" />
                <span className="text-xs font-semibold uppercase tracking-wider text-white/70 mb-2">
                  {activeType.label}
                </span>
                <h3 className="text-4xl font-bold drop-shadow-md">{activeType.intent}</h3>
                <p className="text-white/90 text-lg mt-3 drop-shadow-sm max-w-md">
                  {activeType.description}
                </p>
              </div>

              {/* Content side */}
              <div className="p-10 sm:p-14 flex flex-col justify-center">
                <ul className="space-y-4 mb-8">
                  {activeFeatures.map(feature => (
                    <li key={feature.text} className="flex items-center gap-3 text-gray-700">
                      <feature.icon
                        className="w-5 h-5 shrink-0"
                        style={{ color: activeType.colorVar }}
                      />
                      <span className="font-medium">{feature.text}</span>
                    </li>
                  ))}
                </ul>
                {activeType.comingSoon ? (
                  <span className="inline-flex w-fit items-center justify-center rounded-2xl border-2 border-gray-200 px-6 py-4 font-bold text-gray-400">
                    Coming soon
                  </span>
                ) : (
                  <button
                    onClick={() => navigate(activeType.route)}
                    className={`w-fit bg-gradient-to-r ${activeType.gradient} text-white rounded-2xl px-8 py-4 font-bold hover:opacity-90 hover:scale-105 transition-all shadow-md hover:shadow-xl`}
                  >
                    Get started →
                  </button>
                )}
              </div>
            </div>

            {/* Prev / next arrows */}
            <button
              type="button"
              aria-label="Previous card type"
              onClick={() => goToSlide(activeSlide - 1)}
              className="absolute left-2 sm:-left-5 top-1/2 -translate-y-1/2 flex items-center justify-center w-11 h-11 rounded-full bg-white shadow-lg hover:scale-110 transition-all text-gray-700"
            >
              <ChevronLeft className="w-6 h-6" />
            </button>
            <button
              type="button"
              aria-label="Next card type"
              onClick={() => goToSlide(activeSlide + 1)}
              className="absolute right-2 sm:-right-5 top-1/2 -translate-y-1/2 flex items-center justify-center w-11 h-11 rounded-full bg-white shadow-lg hover:scale-110 transition-all text-gray-700"
            >
              <ChevronRight className="w-6 h-6" />
            </button>

            {/* Dots */}
            <div className="flex justify-center items-center gap-3 mt-6">
              {cardTypes.map((type, index) => {
                const isActive = index === activeSlide;
                return (
                  <button
                    key={type.id}
                    type="button"
                    aria-label={`Show ${type.label}`}
                    aria-current={isActive}
                    onClick={() => goToSlide(index)}
                    className={`h-2.5 rounded-full transition-all ${isActive ? 'w-8' : 'w-2.5 bg-gray-300 hover:bg-gray-400'}`}
                    style={isActive ? { backgroundColor: type.colorVar } : undefined}
                  />
                );
              })}
            </div>
          </div>
        </Reveal>

        {/* Quick Occasion Links */}
        <Reveal>
          <div className="w-full max-w-6xl mx-auto mt-8">
            <h2 className="text-2xl md:text-3xl font-bold text-gray-900 mb-6">
              Or browse by occasion
            </h2>
            <div className="flex flex-wrap justify-center gap-3 mb-8">
              {occasions.slice(0, 12).map(occasion => {
                const destination = occasion.hasLandingPage
                  ? `/for/${occasion.slug}`
                  : `/group-card/new?occasion=${encodeURIComponent(occasion.name)}`;
                return (
                  <Link
                    key={occasion.slug}
                    to={destination}
                    className="px-6 py-3 bg-white rounded-full shadow-md hover:shadow-xl hover:scale-105 transition-all font-semibold text-gray-900 border-2 border-gray-200 hover:border-purple-300"
                  >
                    {occasion.name}
                  </Link>
                );
              })}
            </div>
            <Link
              to="/occasions"
              className="inline-block text-purple-600 hover:text-purple-700 font-bold text-lg hover:scale-105 transition-all"
            >
              View All Occasions →
            </Link>
          </div>
        </Reveal>
      </section>

      {/* Open-source section */}
      <section className="scroll-section bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900 min-h-screen overflow-y-hidden flex flex-col justify-center items-center px-4 py-[5vh] relative w-full">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-1/3 right-1/4 w-96 h-96 bg-green-500/10 rounded-full blur-3xl"></div>
          <div className="absolute bottom-1/4 left-1/4 w-96 h-96 bg-blue-600/20 rounded-full blur-3xl"></div>
        </div>

        <Reveal>
          <div className="max-w-4xl mx-auto text-center relative z-10">
            <div className="flex justify-center mb-6">
              <div className="flex items-center justify-center w-16 h-16 rounded-2xl bg-white/10 border border-white/20 backdrop-blur-sm">
                <Github className="w-8 h-8 text-white" />
              </div>
            </div>
            <h2 className="text-white text-4xl md:text-6xl font-black mb-6">Built in the open</h2>
            <p className="text-white/80 text-lg md:text-2xl font-medium mb-10 max-w-2xl mx-auto">
              CardJoy is fully open source. Inspect the code, self-host it, or contribute — no
              lock-in, no hidden data practices, no paywalls.
            </p>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mb-12 text-left">
              {[
                {
                  title: 'Transparent',
                  desc: 'Every line of code is public. See exactly how your data is handled.',
                },
                {
                  title: 'Self-hostable',
                  desc: 'Run CardJoy on your own infrastructure whenever you want.',
                },
                {
                  title: 'Community-driven',
                  desc: 'Built with contributors. Open an issue or a pull request anytime.',
                },
              ].map(item => (
                <div
                  key={item.title}
                  className="rounded-2xl bg-white/5 border border-white/10 p-6 backdrop-blur-sm"
                >
                  <h3 className="text-white text-xl font-bold mb-2">{item.title}</h3>
                  <p className="text-white/70 text-base leading-relaxed">{item.desc}</p>
                </div>
              ))}
            </div>

            <a
              href={GITHUB_REPO_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-3 bg-white text-gray-900 rounded-2xl px-10 py-5 font-bold text-lg hover:scale-105 transition-all shadow-xl hover:shadow-2xl"
            >
              <Star className="w-5 h-5 text-[var(--color-brand-yellow)]" />
              Star us on GitHub
            </a>
          </div>
        </Reveal>
      </section>

      {/* FAQ Section */}
      <section className="scroll-section bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50 min-h-screen overflow-y-hidden flex flex-col justify-center items-center px-4 py-[5vh] w-full">
        <Reveal>
          <Faq />
        </Reveal>
      </section>

      {/* Business handoff band */}
      <section className="bg-gray-900 py-12 px-4 w-full">
        <Reveal>
          <div className="max-w-5xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-6 text-center sm:text-left">
            <div className="flex items-center gap-4">
              <div className="flex items-center justify-center w-12 h-12 rounded-xl bg-white/10 border border-white/20 shrink-0">
                <Building2 className="w-6 h-6 text-white" />
              </div>
              <div>
                <h3 className="text-white text-xl font-bold">Using CardJoy for your business?</h3>
                <p className="text-white/70">
                  Group cards your team signs in Slack, and reminders before your clients&apos; big
                  days.
                </p>
              </div>
            </div>
            <Link
              to="/for-business"
              className="group inline-flex items-center gap-2 bg-white text-gray-900 rounded-2xl px-7 py-4 font-bold hover:scale-105 transition-all shadow-lg whitespace-nowrap"
            >
              CardJoy for Business
              <ArrowRight className="w-5 h-5 group-hover:translate-x-0.5 transition-transform" />
            </Link>
          </div>
        </Reveal>
      </section>

      {/* Final CTA Section */}
      <section className="scroll-section bg-gradient-to-br from-purple-600 via-pink-500 to-blue-600 min-h-[60vh] overflow-y-hidden flex flex-col justify-center items-center px-4 py-16 w-full">
        <Reveal>
          <div className="max-w-4xl mx-auto text-center space-y-6 sm:space-y-8">
            <h2 className="text-white text-3xl sm:text-4xl md:text-6xl font-black leading-tight">
              Let's get the party started
            </h2>
            <p className="text-white/90 text-lg sm:text-xl md:text-2xl font-medium mb-4">
              5 free credits to start. Open source. Start in seconds — no credit card required.
            </p>
            <div className="flex justify-center">
              <IntentPickerDialog>
                <button className="bg-white text-gray-900 rounded-2xl px-8 py-5 flex items-center justify-center gap-3 hover:scale-105 transition-all shadow-xl hover:shadow-2xl w-full sm:w-auto">
                  <Sparkles className="w-5 h-5" />
                  <span className="text-lg font-bold">{createCtaLabel}</span>
                </button>
              </IntentPickerDialog>
            </div>
          </div>
        </Reveal>
      </section>
    </div>
  );
};

export default Home;
