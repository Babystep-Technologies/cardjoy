import { motion } from 'motion/react';
import type { ReactNode } from 'react';

interface SparkleProps {
  children: ReactNode;
  duration?: number;
}

export function Sparkle({ children, duration = 1500 }: SparkleProps) {
  return (
    <motion.div
      className="w-full h-full relative"
      initial={{ opacity: 0, filter: 'blur(20px)' }}
      animate={{ opacity: 1, filter: 'blur(0px)' }}
      transition={{ duration: duration / 1000, ease: 'easeOut' }}
    >
      {/* Glow effect */}
      <motion.div
        className="absolute inset-0 pointer-events-none"
        initial={{ opacity: 0 }}
        animate={{ opacity: [0, 0.5, 0] }}
        transition={{ duration: duration / 1000, times: [0, 0.5, 1] }}
        style={{
          background: 'radial-gradient(circle, rgba(255,255,255,0.3) 0%, transparent 70%)',
        }}
      />
      {children}
    </motion.div>
  );
}
