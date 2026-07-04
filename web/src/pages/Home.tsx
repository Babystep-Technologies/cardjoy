import React from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { WordRotate } from '@/components/magicui/word-rotate';
import * as motion from 'motion/react-client';
import Reveal from '@/components/Reveal';
import Faq from '@/pages/Home/Faq';
import { Heart, Cake, Baby, GraduationCap, Briefcase } from 'lucide-react';
import { UseCaseCard } from '@/components/UseCaseCard';
import { occasions } from '@/config/occasions';

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
        </Reveal>

        <motion.div
          className="mt-8 sm:mt-12 relative z-10 mx-4"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.6 }}
        >
          <button
            onClick={() => navigate('/card/new')}
            className="group bg-white text-gray-900 rounded-2xl px-10 py-6 flex items-center gap-3 hover:scale-105 transition-all shadow-xl hover:shadow-2xl"
          >
            <span className="text-xl font-bold">Create for Your Moment</span>
          </button>
        </motion.div>
      </section>

      <section className="scroll-section bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50 min-h-screen overflow-y-hidden flex flex-col justify-center items-center py-[5vh] px-4 text-center">
        <Reveal>
          <h1 className="text-gray-900 text-4xl md:text-6xl pt-12 font-black mb-4">
            Every moment, made memorable
          </h1>
          <p className="text-gray-600 text-lg md:text-2xl font-medium mb-12">
            From small gestures to big celebrations
          </p>
        </Reveal>

        {/* Use-Case Storytelling Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 max-w-7xl mx-auto mb-16">
          <Reveal>
            <UseCaseCard
              story="Sarah's team surprised her with 47 birthday messages from across 3 offices"
              occasion="Celebrate a colleague"
              link="/for/birthday"
              icon={Cake}
              gradient="from-pink-400 to-purple-500"
            />
          </Reveal>
          <Reveal>
            <UseCaseCard
              story="When Jordan's team was downsized, colleagues rallied to send a goodbye card that made the hardest day a little brighter"
              occasion="Support a laid-off colleague"
              link="/for/job-farewell"
              icon={Heart}
              gradient="from-amber-400 to-orange-500"
            />
          </Reveal>
          <Reveal>
            <UseCaseCard
              story="Emma's baby shower became a digital keepsake with messages from 60 loved ones"
              occasion="Welcome the new baby"
              link="/for/baby-shower"
              icon={Baby}
              gradient="from-blue-400 to-cyan-500"
            />
          </Reveal>
          <Reveal>
            <UseCaseCard
              story="Alex's family from 12 different states all signed one graduation card"
              occasion="Congratulate your graduate"
              link="/for/graduation"
              icon={GraduationCap}
              gradient="from-yellow-400 to-orange-500"
            />
          </Reveal>
          <Reveal>
            <UseCaseCard
              story="150 wedding guests left notes that the couple will read for years to come"
              occasion="Celebrate love together"
              link="/for/wedding"
              icon={Heart}
              gradient="from-rose-400 to-pink-500"
            />
          </Reveal>
          <Reveal>
            <UseCaseCard
              story="Jake's new job celebration included messages from mentors, colleagues, and friends"
              occasion="Cheer on the promotion"
              link="/for/new-job"
              icon={Briefcase}
              gradient="from-green-400 to-emerald-500"
            />
          </Reveal>
        </div>

        {/* Quick Occasion Links */}
        <Reveal>
          <div className="w-full max-w-6xl mx-auto">
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
            <h1 className="text-white text-3xl sm:text-4xl md:text-6xl font-black leading-tight">
              Let's get the party started
            </h1>
            <p className="text-white/90 text-lg sm:text-xl md:text-2xl font-medium mb-4">
              100% free, no credit card required
            </p>
            <button
              onClick={() => navigate('/card/new')}
              className="bg-white text-gray-900 rounded-2xl px-10 py-6 flex items-center justify-center gap-3 hover:scale-105 transition-all shadow-xl hover:shadow-2xl mx-auto"
            >
              <span className="text-xl font-bold">Create for Your Moment</span>
            </button>
          </div>
        </Reveal>
      </section>
    </div>
  );
};

export default Home;
