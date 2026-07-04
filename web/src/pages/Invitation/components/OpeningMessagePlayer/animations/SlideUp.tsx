import { motion } from 'motion/react';
import type { ReactNode } from 'react';

interface SlideUpProps {
  children: ReactNode;
  duration?: number;
}

export function SlideUp({ children, duration = 1200 }: SlideUpProps) {
  return (
    <motion.div
      className="w-full h-full"
      initial={{ opacity: 0, y: 60 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: duration / 1000,
        ease: [0.25, 0.46, 0.45, 0.94],
      }}
    >
      {children}
    </motion.div>
  );
}
