import { useEffect, useRef, useState } from 'react';
import * as motion from 'motion/react-client';

interface RevealProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  duration?: number;
  once?: boolean;
}

const Reveal: React.FC<RevealProps> = ({
  children,
  className = '',
  delay = 0,
  duration = 0.6,
  once = true,
}) => {
  const ref = useRef<HTMLDivElement | null>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          if (once) observer.disconnect();
        } else if (!once) {
          setIsVisible(false);
        }
      },
      {
        threshold: 0.2,
      }
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, [once]);

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 40 }}
      animate={isVisible ? { opacity: 1, y: 0 } : { opacity: 0, y: 40 }}
      transition={{
        duration,
        delay,
        ease: [0.33, 1, 0.68, 1],
      }}
      className={className}
    >
      {children}
    </motion.div>
  );
};

export default Reveal;
