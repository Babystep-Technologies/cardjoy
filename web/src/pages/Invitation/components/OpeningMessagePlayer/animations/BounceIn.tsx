import { motion } from 'motion/react';
import type { ReactNode } from 'react';

interface BounceInProps {
  children: ReactNode;
  duration?: number;
}

export function BounceIn({ children, duration = 1200 }: BounceInProps) {
  return (
    <motion.div
      className="w-full h-full"
      initial={{ opacity: 0, scale: 0.3, y: -50 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      transition={{
        type: 'spring',
        stiffness: 260,
        damping: 20,
        duration: duration / 1000,
      }}
    >
      {children}
    </motion.div>
  );
}
