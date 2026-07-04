import { motion } from 'motion/react';
import { useEffect, type ReactNode } from 'react';
import confetti from 'canvas-confetti';

interface ConfettiPopProps {
  children: ReactNode;
  duration?: number;
}

export function ConfettiPop({ children, duration = 1200 }: ConfettiPopProps) {
  useEffect(() => {
    // Trigger confetti after a short delay for the scale animation to start
    const timer = setTimeout(() => {
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 },
        colors: ['#ff6b6b', '#feca57', '#48dbfb', '#ff9ff3', '#54a0ff'],
      });
    }, 200);

    return () => clearTimeout(timer);
  }, []);

  return (
    <motion.div
      className="w-full h-full"
      initial={{ opacity: 0, scale: 0.5 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{
        type: 'spring',
        stiffness: 200,
        damping: 15,
        duration: duration / 1000,
      }}
    >
      {children}
    </motion.div>
  );
}
