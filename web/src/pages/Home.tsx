import React from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { WordRotate } from '@/components/magicui/word-rotate';
import * as motion from 'motion/react-client';
import Reveal from '@/components/Reveal';
import Faq from '@/pages/Home/Faq';
import {
  Mail,
  PartyPopper,
  Github,
  Star,
  Check,
  CalendarCheck,
  QrCode,
  Users,
  Sparkles,
} from 'lucide-react';
import { occasions } from '@/config/occasions';
import { GITHUB_REPO_URL } from '@/lib/constants';

const cardFeatures = [
  { icon: Users, text: 'No signup needed for contributors' },
  { icon: Sparkles, text: 'Works for any occasion' },
  { icon: QrCode, text: 'QR code for in-person events' },
];

const invitationFeatures = [
  { icon: Sparkles, text: 'Animated opening screen' },
  { icon: Check, text: 'Built-in RSVP tracking' },
  { icon: CalendarCheck, text: 'One-tap add to calendar' },
];

const Home: React.FC = () => {
  const navigate = useNavigate();

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

        {/* Decorative elements */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-20 left-10 w-16 h-16 bg-pink-400/20 rounded-full blur-sm animate-bounce" />
          <div className="absolute top-40 right-20 w-14 h-14 bg-purple-400/20 rounded-full blur-sm" />
          <div className="absolute bottom-32 left-20 w-12 h-12 bg-yellow-400/20 rounded-full blur-sm" />
          <div className="absolute bottom-20 right-10 w-16 h-16 bg-blue-400/20 rounded-full blur-sm" />
        </div>

        <Reveal>
          {/* Open-source badge */}
          <div className="flex justify-center mb-6 relative z-10">
            <a
              href={GITHUB_REPO_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/10 border border-white/20 text-white text-sm font-medium backdrop-blur-sm hover:bg-white/20 transition-all"
            >
              <Star className="w-4 h-4 text-[var(--color-brand-yellow)]" />
              Open source &amp; 100% free
              <Github className="w-4 h-4" />
            </a>
          </div>

          <h1 className="text-white text-4xl md:text-6xl font-bold text-center px-6 relative z-10">
            Make Life Moments Shine
            <WordRotate
              className="text-4xl md:text-6xl font-bold text-center px-6"
              words={[
                "Celebrate a Colleague's Birthday",
                'Say Goodbye to a Friend',
                'Welcome the New Baby',
                'Congratulate Your Graduate',
              ]}
              colors={[
                'text-[var(--color-brand-pink)]',
                'text-[var(--color-brand-yellow)]',
                'text-[var(--color-brand-blue)]',
                'text-[var(--color-brand-green)]',
              ]}
            />
          </h1>

          <p className="text-white/80 text-lg md:text-2xl font-medium text-center px-6 mt-6 relative z-10 max-w-2xl mx-auto">
            Group cards and event invitations — beautiful, free, and open source.
          </p>
        </Reveal>

        <motion.div
          className="mt-8 sm:mt-12 relative z-10 mx-4 flex flex-col sm:flex-row items-center gap-4"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.6 }}
        >
          <button
            onClick={() => navigate('/card/new')}
            className="group bg-white text-gray-900 rounded-2xl px-8 py-5 flex items-center justify-center gap-3 hover:scale-105 transition-all shadow-xl hover:shadow-2xl w-full sm:w-auto"
          >
            <Mail className="w-5 h-5" />
            <span className="text-lg font-bold">Create a Card</span>
          </button>
          <button
            onClick={() => navigate('/invitation/new')}
            className="group bg-white/10 text-white border border-white/30 rounded-2xl px-8 py-5 flex items-center justify-center gap-3 hover:bg-white/20 hover:scale-105 transition-all backdrop-blur-sm w-full sm:w-auto"
          >
            <PartyPopper className="w-5 h-5" />
            <span className="text-lg font-bold">Create an Invitation</span>
          </button>
        </motion.div>
      </section>

      {/* Two-products showcase */}
      <section className="scroll-section bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50 min-h-screen overflow-y-hidden flex flex-col justify-center items-center py-[5vh] px-4 text-center">
        <Reveal>
          <h2 className="text-gray-900 text-4xl md:text-6xl pt-12 font-black mb-4">
            Two ways to celebrate
          </h2>
          <p className="text-gray-600 text-lg md:text-2xl font-medium mb-12">
            Bring people together — before and after the moment
          </p>
        </Reveal>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 max-w-6xl mx-auto w-full mb-8">
          {/* Group Cards */}
          <Reveal>
            <div className="h-full flex flex-col rounded-3xl bg-white shadow-lg hover:shadow-2xl transition-all overflow-hidden text-left">
              <div className="bg-gradient-to-br from-[var(--color-brand-pink)] to-[var(--color-brand-blue)] p-8 text-white">
                <Mail className="w-12 h-12 drop-shadow-lg mb-4" />
                <h3 className="text-3xl font-bold drop-shadow-md">Group Cards</h3>
                <p className="text-white/90 text-lg mt-2 drop-shadow-sm">
                  Collect heartfelt messages, photos &amp; wishes from everyone who cares — all in
                  one beautiful keepsake.
                </p>
              </div>
              <div className="flex flex-col flex-1 p-8">
                <ul className="space-y-3 flex-1">
                  {cardFeatures.map(feature => (
                    <li key={feature.text} className="flex items-center gap-3 text-gray-700">
                      <feature.icon className="w-5 h-5 text-[var(--color-brand-pink)] shrink-0" />
                      <span className="font-medium">{feature.text}</span>
                    </li>
                  ))}
                </ul>
                <button
                  onClick={() => navigate('/card/new')}
                  className="mt-8 bg-gray-900 text-white rounded-2xl px-6 py-4 font-bold hover:scale-105 transition-all shadow-md hover:shadow-xl"
                >
                  Create a Card →
                </button>
              </div>
            </div>
          </Reveal>

          {/* Invitations */}
          <Reveal>
            <div className="h-full flex flex-col rounded-3xl bg-white shadow-lg hover:shadow-2xl transition-all overflow-hidden text-left">
              <div className="bg-gradient-to-br from-[var(--color-brand-blue)] to-[var(--color-brand-green)] p-8 text-white">
                <PartyPopper className="w-12 h-12 drop-shadow-lg mb-4" />
                <h3 className="text-3xl font-bold drop-shadow-md">Invitations</h3>
                <p className="text-white/90 text-lg mt-2 drop-shadow-sm">
                  Design animated invites your guests will love, with RSVP tracking and event
                  details built right in.
                </p>
              </div>
              <div className="flex flex-col flex-1 p-8">
                <ul className="space-y-3 flex-1">
                  {invitationFeatures.map(feature => (
                    <li key={feature.text} className="flex items-center gap-3 text-gray-700">
                      <feature.icon className="w-5 h-5 text-[var(--color-brand-blue)] shrink-0" />
                      <span className="font-medium">{feature.text}</span>
                    </li>
                  ))}
                </ul>
                <button
                  onClick={() => navigate('/invitation/new')}
                  className="mt-8 bg-gray-900 text-white rounded-2xl px-6 py-4 font-bold hover:scale-105 transition-all shadow-md hover:shadow-xl"
                >
                  Create an Invitation →
                </button>
              </div>
            </div>
          </Reveal>
        </div>

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
                  : `/card/new?occasion=${encodeURIComponent(occasion.name)}`;
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

      {/* Final CTA Section */}
      <section className="scroll-section bg-gradient-to-br from-purple-600 via-pink-500 to-blue-600 min-h-[60vh] overflow-y-hidden flex flex-col justify-center items-center px-4 py-16 w-full">
        <Reveal>
          <div className="max-w-4xl mx-auto text-center space-y-6 sm:space-y-8">
            <h2 className="text-white text-3xl sm:text-4xl md:text-6xl font-black leading-tight">
              Let's get the party started
            </h2>
            <p className="text-white/90 text-lg sm:text-xl md:text-2xl font-medium mb-4">
              Free forever. Open source. Start in seconds — no credit card required.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <button
                onClick={() => navigate('/card/new')}
                className="bg-white text-gray-900 rounded-2xl px-8 py-5 flex items-center justify-center gap-3 hover:scale-105 transition-all shadow-xl hover:shadow-2xl w-full sm:w-auto"
              >
                <Mail className="w-5 h-5" />
                <span className="text-lg font-bold">Create a Card</span>
              </button>
              <button
                onClick={() => navigate('/invitation/new')}
                className="bg-white/15 text-white border border-white/40 rounded-2xl px-8 py-5 flex items-center justify-center gap-3 hover:bg-white/25 hover:scale-105 transition-all backdrop-blur-sm w-full sm:w-auto"
              >
                <PartyPopper className="w-5 h-5" />
                <span className="text-lg font-bold">Create an Invitation</span>
              </button>
            </div>
          </div>
        </Reveal>
      </section>
    </div>
  );
};

export default Home;
