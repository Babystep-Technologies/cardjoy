import React, { useRef, useEffect, useState } from 'react';

type CardData = {
  externalId: string;
  coverImageUrl: string | null;
  qrCodeUrl: string | null;
  title: string;
  recipients: string[];
};

interface TiltCardProps {
  cardExternalIds: string[];
  className?: string;
  intervalMs?: number;
}

// Hardcoded card data for demo purposes
const HARDCODED_CARDS: CardData[] = [
  {
    externalId: 'MXATRQO',
    coverImageUrl: 'https://cdn.cardjoy.app/73zyhvxwhblg5uw01orsvv79a9k3',
    qrCodeUrl: 'https://cdn.cardjoy.app/xky5xsbneb0ahspjy79wlp0kceyl',
    title: 'Birthday Bash',
    recipients: ['Alex'],
  },
  {
    externalId: 'VQIWXEM',
    coverImageUrl: 'https://cdn.cardjoy.app/t10tbhmmn4jkzog41xg9i1inhaxv',
    qrCodeUrl: 'https://cdn.cardjoy.app/3d6xcw44gbw9v9jatm2mwtglp5ri',
    title: 'Wedding Party',
    recipients: ['Sam & Jamie'],
  },
  {
    externalId: 'ICRKFQH',
    coverImageUrl: 'https://cdn.cardjoy.app/i2d6r4hy14mnhh4qs3rbvx0h6ws5',
    qrCodeUrl: 'https://cdn.cardjoy.app/wrshow6m40v0vvrp3uaks46p71x9',
    title: 'Baby Shower',
    recipients: ['Taylor'],
  },
];

const TiltCard: React.FC<TiltCardProps> = ({
  cardExternalIds,
  className = '',
  intervalMs = 5000,
}) => {
  const cardRef = useRef<HTMLDivElement>(null);
  const [cards, setCards] = useState<CardData[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isTransitioning, setIsTransitioning] = useState(false);

  useEffect(() => {
    // Filter the hardcoded cards by the provided external IDs
    setCards(HARDCODED_CARDS.filter(card => cardExternalIds.includes(card.externalId)));
  }, [cardExternalIds]);

  useEffect(() => {
    if (cards.length <= 1) return;
    const interval = setInterval(() => {
      setIsTransitioning(true);
      setTimeout(() => {
        setCurrentIndex(prev => (prev + 1) % cards.length);
        setIsTransitioning(false);
      }, 250); // Half of the transition duration
    }, intervalMs);
    return () => clearInterval(interval);
  }, [cards.length, intervalMs]);

  const handlePointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const card = cardRef.current;
    if (!card) return;
    const rect = card.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    const rotateX = -((y - centerY) / centerY) * 10;
    const rotateY = ((x - centerX) / centerX) * 10;
    card.animate(
      {
        transform: `rotateX(${rotateX}deg) rotateY(${rotateY}deg)`,
      },
      { duration: 300, fill: 'forwards' }
    );
  };

  const handlePointerLeave = () => {
    const card = cardRef.current;
    if (!card) return;
    card.animate(
      { transform: 'rotateX(0deg) rotateY(0deg)' },
      {
        duration: 300,
        fill: 'forwards',
        easing: 'ease-out',
      }
    );
  };

  // Responsive overlay styles
  const [isMobile, setIsMobile] = React.useState(false);
  React.useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 640);
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  if (cards.length === 0) {
    return (
      <div
        className={`w-full max-w-2xl mx-auto aspect-[4/3] rounded-xl shadow-lg overflow-hidden relative bg-gray-200 flex items-center justify-center ${className}`}
      >
        <span className="text-gray-500 text-lg">Loading...</span>
      </div>
    );
  }

  const card = cards[currentIndex];

  // Responsive card width: at least 50vw on desktop, 80vw on mobile
  const getCardWidth = () => {
    if (isMobile) return '80vw';
    return '50vw';
  };

  return (
    <section
      className="w-full flex items-center justify-center min-h-[400px]"
      style={{ minHeight: '400px' }}
    >
      <div
        ref={cardRef}
        onPointerMove={handlePointerMove}
        onPointerLeave={handlePointerLeave}
        className={`aspect-[4/2.7] rounded-xl shadow-lg overflow-hidden relative flex-none transition-opacity duration-500 ${
          isTransitioning ? 'opacity-0' : 'opacity-100'
        } ${className}`}
        style={{
          width: getCardWidth(),
          maxWidth: '900px',
          minWidth: isMobile ? '240px' : '400px',
          minHeight: isMobile ? '400px' : '320px',
          transformStyle: 'preserve-3d',
          background: card.coverImageUrl
            ? `url(${card.coverImageUrl}) center/cover no-repeat`
            : '#fff',
          transition: 'width 0.2s, min-height 0.2s, opacity 0.5s ease-in-out',
        }}
      >
        {/* Black overlay with 0.2 opacity */}
        <div
          className="absolute inset-0 bg-black"
          style={{ opacity: 0.2, zIndex: 1, pointerEvents: 'none' }}
        />
        {/* Content overlay, text is now white and bold, positioned absolutely */}
        <div
          className="absolute inset-0 flex flex-col items-center justify-center px-4"
          style={{ zIndex: 2, pointerEvents: 'none' }}
        >
          <div
            className="flex flex-col items-center justify-center gap-4 w-full"
            style={{ lineHeight: 1.2 }}
          >
            {card.qrCodeUrl && (
              <div className="flex items-center justify-center w-full">
                <img
                  src={card.qrCodeUrl}
                  alt="QR Code"
                  className="mx-auto w-32 h-32 object-contain"
                  style={{ background: 'white', borderRadius: isMobile ? '0' : '0.75rem' }}
                />
              </div>
            )}
            <h1 className="text-3xl text-white">scan to share a message</h1>
            <div className="text-2xl font-extrabold text-white drop-shadow-lg">
              <h1>{card.title}</h1>
              {card.recipients.length > 0 && <h1> for {card.recipients.join(', ')}</h1>}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default TiltCard;
