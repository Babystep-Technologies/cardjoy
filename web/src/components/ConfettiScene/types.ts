import type { MotionValue } from 'motion/react';

export interface ConfettiSceneConfig {
  canvas: HTMLCanvasElement;
  particleCount: number;
  backgroundColor: string;
  scrollProgress: MotionValue<number>;
}

export interface ConfettiRenderer {
  init: () => void;
  destroy: () => void;
  triggerBurst: (intensity?: number) => void;
}

export interface ConfettiSceneHandle {
  triggerBurst: (intensity?: number) => void;
}

export interface ConfettiSceneProps {
  backgroundColor?: string;
  /** Total number of message sections, used to detect section transitions */
  sectionCount?: number;
}
