import { useRef } from 'react';
import { motion, useScroll, useTransform } from 'motion/react';

type Message = {
  id: string;
  title: string;
  text: string;
  imageUrl?: string | null;
  user?: { id?: string; name?: string } | null;
  name?: string | null;
  displayName?: string;
  kind: string;
};

interface ScrollStorySectionProps {
  message: Message;
  textColor: string;
  isLast?: boolean;
}

const ScrollStorySection: React.FC<ScrollStorySectionProps> = ({
  message,
  textColor,
  isLast = false,
}) => {
  const sectionRef = useRef<HTMLDivElement>(null);

  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ['start end', 'end start'],
  });

  // progress: 0 = section entering from bottom, 0.5 = centered, 1.0 = exiting top

  // Container: zoom in from small + fade, hold, then zoom out + fade
  const opacity = useTransform(scrollYProgress, [0.05, 0.25, 0.7, 0.95], [0, 1, 1, 0]);
  const scale = useTransform(scrollYProgress, [0.05, 0.3, 0.65, 0.95], [0.6, 1, 1, 0.6]);
  const y = useTransform(scrollYProgress, [0.05, 0.3, 0.65, 0.95], [120, 0, 0, -120]);

  // Title: leads the entrance, slightly bigger zoom
  const titleOpacity = useTransform(scrollYProgress, [0.02, 0.2, 0.7, 0.92], [0, 1, 1, 0]);
  const titleScale = useTransform(scrollYProgress, [0.02, 0.25, 0.65, 0.92], [0.4, 1, 1, 0.4]);
  const titleY = useTransform(scrollYProgress, [0.02, 0.25, 0.65, 0.92], [60, 0, 0, -60]);

  // Body text: follows title
  const bodyOpacity = useTransform(scrollYProgress, [0.1, 0.3, 0.68, 0.9], [0, 1, 1, 0]);
  const bodyY = useTransform(scrollYProgress, [0.1, 0.3, 0.68, 0.9], [40, 0, 0, -40]);

  // Author: fades in last
  const authorOpacity = useTransform(scrollYProgress, [0.2, 0.38, 0.65, 0.85], [0, 1, 1, 0]);
  const authorY = useTransform(scrollYProgress, [0.2, 0.38, 0.65, 0.85], [20, 0, 0, -20]);

  // Image
  const imageOpacity = useTransform(scrollYProgress, [0.08, 0.28, 0.68, 0.9], [0, 1, 1, 0]);
  const imageScale = useTransform(scrollYProgress, [0.08, 0.28, 0.68, 0.9], [0.7, 1, 1, 0.7]);

  const authorName = 'user' in message ? message.displayName || message.user?.name : message.name;

  return (
    <div
      ref={sectionRef}
      className="relative flex items-center justify-center"
      style={{
        height: isLast ? '100vh' : '130vh',
        minHeight: '600px',
      }}
    >
      <motion.div
        className="flex flex-col items-center justify-center max-w-2xl mx-auto px-6 text-center"
        style={{ opacity, scale, y }}
      >
        {/* Image */}
        {message.imageUrl && (
          <motion.div
            className="mb-8 w-full max-w-md overflow-hidden rounded-2xl shadow-lg"
            style={{ opacity: imageOpacity, scale: imageScale }}
          >
            <img src={message.imageUrl} alt="" className="w-full object-cover" />
          </motion.div>
        )}

        {/* Title */}
        <motion.h2
          className="text-3xl sm:text-4xl md:text-5xl font-bold mb-6 leading-tight"
          style={{
            color: textColor,
            opacity: titleOpacity,
            scale: titleScale,
            y: titleY,
          }}
        >
          {message.title}
        </motion.h2>

        {/* Body text */}
        <motion.p
          className="text-lg sm:text-xl md:text-2xl leading-relaxed whitespace-pre-line max-w-xl"
          style={{
            color: textColor,
            opacity: bodyOpacity,
            y: bodyY,
          }}
        >
          {message.text}
        </motion.p>

        {/* Author */}
        {authorName && (
          <motion.span
            className="mt-8 text-base sm:text-lg italic"
            style={{
              color: textColor,
              opacity: authorOpacity,
              y: authorY,
            }}
          >
            — {authorName}
          </motion.span>
        )}
      </motion.div>
    </div>
  );
};

export default ScrollStorySection;
