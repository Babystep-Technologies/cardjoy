import { motion } from 'motion/react';
import { useMemo } from 'react';

import { cn } from '@/lib/utils';

interface HeartFieldProps {
  count?: number;
  className?: string;
}

interface Heart {
  id: string;
  x: string;
  size: number;
  opacity: number;
  delay: number;
  duration: number;
  drift: number;
}

/**
 * Brand-pink hearts drifting up from the bottom edge. Fills its nearest
 * positioned ancestor, same as `SparkleField`.
 */
const HeartField: React.FC<HeartFieldProps> = ({ count = 12, className }) => {
  const hearts = useMemo<Heart[]>(
    () =>
      Array.from({ length: count }, (_, i) => ({
        id: `heart-${i}`,
        x: `${Math.random() * 90 + 5}%`,
        size: Math.random() * 16 + 14,
        opacity: Math.random() * 0.4 + 0.45,
        delay: Math.random() * 6,
        duration: Math.random() * 4 + 7,
        drift: Math.random() * 40 - 20,
      })),
    [count]
  );

  return (
    <div className={cn('pointer-events-none absolute inset-0 overflow-hidden', className)}>
      {hearts.map(heart => (
        // The track spans the container, so `y` is a share of the full height
        // and every heart crosses the same distance whatever its size.
        <motion.div
          key={heart.id}
          className="absolute inset-y-0"
          style={{ left: heart.x }}
          initial={{ y: '100%', opacity: 0 }}
          animate={{ y: '-100%', opacity: [0, heart.opacity, heart.opacity, 0] }}
          transition={{
            duration: heart.duration,
            repeat: Infinity,
            delay: heart.delay,
            ease: 'linear',
            opacity: {
              duration: heart.duration,
              repeat: Infinity,
              delay: heart.delay,
              times: [0, 0.15, 0.8, 1],
            },
          }}
        >
          <motion.svg
            className="absolute bottom-0"
            style={{ width: heart.size, height: heart.size }}
            animate={{ x: [0, heart.drift, 0], rotate: [0, heart.drift / 3, 0] }}
            transition={{ duration: 3.5, repeat: Infinity, ease: 'easeInOut' }}
            viewBox="0 0 24 24"
            fill="var(--color-brand-pink)"
          >
            <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
          </motion.svg>
        </motion.div>
      ))}
    </div>
  );
};

export default HeartField;
