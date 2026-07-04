import { useNavigate } from 'react-router-dom';
import { CTAConfig } from '../configs/types';
import Reveal from '../../../components/Reveal';
import { Button } from '../../../components/ui/button';

interface EventCTAProps {
  config: CTAConfig;
  occasion: string;
}

export const EventCTA: React.FC<EventCTAProps> = ({ config, occasion }) => {
  const navigate = useNavigate();

  const handleCTAClick = () => {
    navigate(`/card/new?occasion=${occasion}`);
  };

  return (
    <section className={`py-20 px-4 sm:px-6 lg:px-10 bg-gradient-to-br ${config.gradientClasses}`}>
      <div className="max-w-4xl mx-auto text-center">
        <Reveal>
          <h2 className="text-4xl md:text-6xl font-black text-white mb-6">{config.headline}</h2>
        </Reveal>
        <Reveal delay={0.2}>
          <p className="text-xl md:text-2xl text-white/90 mb-8">{config.description}</p>
        </Reveal>
        <Reveal delay={0.4}>
          <Button
            onClick={handleCTAClick}
            size="lg"
            variant="secondary"
            className="text-lg px-8 py-6 hover:scale-105 transition-all bg-white text-gray-900 hover:bg-gray-100"
          >
            {config.ctaText}
          </Button>
        </Reveal>
      </div>
    </section>
  );
};
