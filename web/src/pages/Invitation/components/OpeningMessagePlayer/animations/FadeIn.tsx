import { motion } from 'motion/react';
import type { ReactNode } from 'react';

interface FadeInProps {
  children: ReactNode;
  duration?: number;
}

export function FadeIn({ children, duration = 1200 }: FadeInProps) {
  return (
    <motion.div
      className="w-full h-full"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: duration / 1000, ease: 'easeOut' }}
    >
      {children}
    </motion.div>
  );
}
