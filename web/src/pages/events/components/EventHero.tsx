import { useNavigate } from 'react-router-dom';
import { HeroConfig } from '../configs/types';
import Reveal from '../../../components/Reveal';
import ImageWithSkeleton from '../../../components/ImageWithSkeleton';
import { Button } from '../../../components/ui/button';

interface EventHeroProps {
  config: HeroConfig;
  occasion: string;
}

export const EventHero: React.FC<EventHeroProps> = ({ config, occasion }) => {
  const navigate = useNavigate();

  const handleCTAClick = () => {
    navigate(`/card/new?occasion=${occasion}`);
  };

  return (
    <section
      className={`min-h-screen flex items-center justify-center bg-gradient-to-br ${config.gradientClasses} px-4 sm:px-6 lg:px-10 py-20`}
    >
      <div className="max-w-6xl mx-auto w-full">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          {/* Text Content */}
          <div className="text-center lg:text-left">
            <Reveal>
              <h1 className="text-5xl md:text-7xl font-black text-gray-900 mb-6">
                {config.headline}
              </h1>
            </Reveal>
            <Reveal delay={0.2}>
              <p className="text-xl md:text-2xl text-gray-700 mb-8">{config.subheadline}</p>
            </Reveal>
            <Reveal delay={0.4}>
              <Button
                onClick={handleCTAClick}
                size="lg"
                className="text-lg px-8 py-6 hover:scale-105 transition-all"
              >
                {config.ctaText}
              </Button>
            </Reveal>
          </div>

          {/* Hero Image */}
          <Reveal delay={0.3}>
            <div className="flex justify-center lg:justify-end">
              <div className="max-w-2xl w-full aspect-[4/3] overflow-hidden rounded-2xl shadow-2xl">
                <ImageWithSkeleton
                  src={config.imageUrl}
                  alt={config.imageAlt}
                  className="w-full h-full object-cover"
                />
              </div>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
};
