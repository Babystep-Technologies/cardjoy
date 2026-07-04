import { motion } from 'motion/react';
import type { ReactNode } from 'react';

interface TypewriterProps {
  children: ReactNode;
  duration?: number;
}

// Wrapper for typewriter effect - splits text into characters
export function Typewriter({ children, duration = 1800 }: TypewriterProps) {
  return (
    <motion.div
      className="w-full h-full"
      initial="hidden"
      animate="visible"
      variants={{
        hidden: { opacity: 1 },
        visible: {
          opacity: 1,
          transition: {
            staggerChildren: Math.min(0.08, duration / 1000 / 30),
          },
        },
      }}
    >
      {children}
    </motion.div>
  );
}

// Component to wrap individual characters for typewriter animation
export function TypewriterText({ text }: { text: string }) {
  return (
    <span aria-label={text}>
      {text.split('').map((char, index) => (
        <motion.span
          key={index}
          variants={{
            hidden: { opacity: 0 },
            visible: { opacity: 1 },
          }}
        >
          {char}
        </motion.span>
      ))}
    </span>
  );
}
