import { useEffect } from 'react';
import { EventLandingConfig } from './configs/types';
import { EventHero } from './components/EventHero';
import { EventFeatures } from './components/EventFeatures';
import { EventCTA } from './components/EventCTA';

interface EventLandingPageProps {
  config: EventLandingConfig;
}

export const EventLandingPage: React.FC<EventLandingPageProps> = ({ config }) => {
  useEffect(() => {
    // Set page title
    document.title = `${config.hero.headline} - CardJoy`;

    // Set meta description
    const metaDescription = document.querySelector('meta[name="description"]');
    if (metaDescription) {
      metaDescription.setAttribute('content', config.hero.subheadline);
    } else {
      const meta = document.createElement('meta');
      meta.name = 'description';
      meta.content = config.hero.subheadline;
      document.head.appendChild(meta);
    }

    // Set theme color
    const themeColor = document.querySelector('meta[name="theme-color"]');
    if (themeColor) {
      themeColor.setAttribute('content', config.theme.primaryColor);
    } else {
      const meta = document.createElement('meta');
      meta.name = 'theme-color';
      meta.content = config.theme.primaryColor;
      document.head.appendChild(meta);
    }

    // Cleanup - restore default theme color on unmount
    return () => {
      const themeColor = document.querySelector('meta[name="theme-color"]');
      if (themeColor) {
        themeColor.setAttribute('content', '#ff69d5'); // Default CardJoy pink
      }
    };
  }, [config]);

  return (
    <div className="min-h-screen">
      <EventHero config={config.hero} occasion={config.occasion} />
      <EventFeatures features={config.features} />
      <EventCTA config={config.cta} occasion={config.occasion} />
    </div>
  );
};
