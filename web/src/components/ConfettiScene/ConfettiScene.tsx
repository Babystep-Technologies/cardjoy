import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { useScroll } from 'motion/react';
import type { ConfettiSceneHandle, ConfettiSceneProps, ConfettiRenderer } from './types';

const ConfettiScene = forwardRef<ConfettiSceneHandle, ConfettiSceneProps>(
  ({ backgroundColor = '#ffffff', sectionCount = 0 }, ref) => {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const rendererRef = useRef<ConfettiRenderer | null>(null);
    const [reducedMotion] = useState(
      () =>
        typeof window !== 'undefined' &&
        window.matchMedia('(prefers-reduced-motion: reduce)').matches
    );
    const { scrollYProgress } = useScroll();

    // Track which section the user is in and burst on transition
    const prevSectionRef = useRef(-1);

    useEffect(() => {
      if (reducedMotion || !canvasRef.current) return;

      let cancelled = false;

      import('./confettiRenderer').then(({ createConfettiRenderer, getParticleCount }) => {
        if (cancelled || !canvasRef.current) return;

        const particleCount = getParticleCount();
        if (particleCount === 0) return;

        const renderer = createConfettiRenderer({
          canvas: canvasRef.current,
          particleCount,
          backgroundColor,
          scrollProgress: scrollYProgress,
        });

        renderer.init();
        rendererRef.current = renderer;
      });

      return () => {
        cancelled = true;
        rendererRef.current?.destroy();
        rendererRef.current = null;
      };
    }, [reducedMotion, backgroundColor, scrollYProgress]);

    // Section transition detection — burst when crossing into a new section
    useEffect(() => {
      if (sectionCount <= 0 || reducedMotion) return;

      const unsubscribe = scrollYProgress.on('change', (progress: number) => {
        // Map [0,1] scroll to section index
        // The page has: hero (takes ~1 section worth) + N message sections + footer spacer
        // Roughly: section = progress * (sectionCount + 1)
        const totalSections = sectionCount + 1; // +1 for hero
        const currentSection = Math.floor(progress * totalSections);

        if (currentSection !== prevSectionRef.current && prevSectionRef.current >= 0) {
          // Crossed a section boundary — burst!
          rendererRef.current?.triggerBurst(1.2);
        }
        prevSectionRef.current = currentSection;
      });

      return unsubscribe;
    }, [sectionCount, scrollYProgress, reducedMotion]);

    useImperativeHandle(
      ref,
      () => ({
        triggerBurst: (intensity?: number) => rendererRef.current?.triggerBurst(intensity),
      }),
      []
    );

    if (reducedMotion) return null;

    return (
      <canvas
        ref={canvasRef}
        style={{
          position: 'fixed',
          inset: 0,
          width: '100%',
          height: '100%',
          zIndex: 10,
          pointerEvents: 'none',
        }}
      />
    );
  }
);

ConfettiScene.displayName = 'ConfettiScene';

export default ConfettiScene;
