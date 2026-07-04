'use client';

import { AnimatePresence, motion, MotionProps } from 'motion/react';
import { useEffect, useState } from 'react';
import { cn } from '@/lib/utils';

interface WordRotateProps {
  words: string[];
  duration?: number;
  motionProps?: MotionProps;
  className?: string;
  colors?: string[];
}

export function WordRotate({
  words,
  duration = 2500,
  motionProps = {
    initial: { opacity: 0, y: -50 },
    animate: { opacity: 1, y: 0 },
    exit: { opacity: 0, y: 50 },
    transition: { duration: 0.25, ease: 'easeOut' },
  },
  className,
  colors,
}: WordRotateProps) {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setIndex(prevIndex => (prevIndex + 1) % words.length);
    }, duration);

    return () => clearInterval(interval);
  }, [words, duration]);

  const colorClass = colors?.[index % (colors?.length || 1)] || '';

  return (
    <div className="overflow-hidden py-2">
      <AnimatePresence mode="wait">
        <motion.h1 key={words[index]} className={cn(className, colorClass)} {...motionProps}>
          {words[index]}
        </motion.h1>
      </AnimatePresence>
    </div>
  );
}
