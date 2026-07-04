import { motion, AnimatePresence } from 'motion/react';
import type {
  OpeningMessageConfig,
  AnimationPreset,
  ImageTransform,
  TextTransform,
} from '@/types/openingMessage';
import { TEMPLATE_COMPONENTS } from './templates';
import { FONTS } from '@/config/openingMessage/themes';
import {
  FadeIn,
  Typewriter,
  TypewriterText,
  SlideUp,
  ConfettiPop,
  BounceIn,
  Sparkle,
} from './animations';
import { Button } from '@/components/ui/button';
import { X } from 'lucide-react';

interface OpeningMessagePlayerProps {
  config: OpeningMessageConfig;
  onComplete: () => void;
  isVisible: boolean;
  previewMode?: boolean;
}

const DEFAULT_TRANSFORM: ImageTransform = {
  x: 0,
  y: 0,
  scale: 1,
  rotation: 0,
};

const DEFAULT_TEXT_TRANSFORM: TextTransform = {
  x: 50,
  y: 50,
  rotation: 0,
  scale: 1,
};

export function OpeningMessagePlayer({
  config,
  onComplete,
  isVisible,
  previewMode = false,
}: OpeningMessagePlayerProps) {
  const {
    template_id,
    text,
    theme = { font: 'poppins', text_color: '#FFFFFF' },
    background = {
      type: 'gradient',
      value: 'from-purple-400 via-pink-400 to-blue-400',
      overlay_opacity: 0,
    },
    animation = { preset: 'fade_in', duration_ms: 1800 },
  } = config;

  const TemplateComponent = TEMPLATE_COMPONENTS[template_id];
  const transform = background.image_transform || DEFAULT_TRANSFORM;
  const textTransform = text.transform || DEFAULT_TEXT_TRANSFORM;
  const fontFamily = FONTS[theme.font]?.fontFamily;

  // Check if text has custom position (not centered)
  const hasCustomTextPosition =
    textTransform.x !== 50 ||
    textTransform.y !== 50 ||
    textTransform.rotation !== 0 ||
    textTransform.scale !== 1;

  const getBackgroundStyle = () => {
    if (background.type === 'color') {
      return { backgroundColor: background.value };
    }
    if (background.type === 'image') {
      // For non-transformed images, use simple background
      if (
        transform.scale === 1 &&
        transform.rotation === 0 &&
        transform.x === 0 &&
        transform.y === 0
      ) {
        return {
          backgroundImage: `url(${background.value})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
        };
      }
      // For transformed images, we'll render via a pseudo-element approach
      return {};
    }
    // gradient - handled via className
    return {};
  };

  const getBackgroundClassName = () => {
    if (background.type === 'gradient') {
      return `bg-gradient-to-br ${background.value}`;
    }
    return '';
  };

  const hasImageTransform =
    background.type === 'image' &&
    background.value &&
    (transform.scale !== 1 || transform.rotation !== 0 || transform.x !== 0 || transform.y !== 0);

  const renderAnimatedContent = () => {
    const content =
      animation.preset === 'typewriter' ? (
        <div
          className="flex flex-col items-center justify-center text-center h-full px-6"
          style={{ color: theme.text_color, fontFamily }}
        >
          <h1 className="text-4xl md:text-6xl font-bold mb-4">
            <TypewriterText text={text.title} />
          </h1>
          {text.subtitle && (
            <p className="text-xl md:text-2xl opacity-90">
              <TypewriterText text={text.subtitle} />
            </p>
          )}
        </div>
      ) : (
        <TemplateComponent text={text} textColor={theme.text_color} fontFamily={fontFamily} />
      );

    const AnimationWrapper = getAnimationWrapper(animation.preset);
    return <AnimationWrapper duration={animation.duration_ms}>{content}</AnimationWrapper>;
  };

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          className={`fixed inset-0 z-[100] flex flex-col ${getBackgroundClassName()}`}
          style={getBackgroundStyle()}
          initial={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.5 }}
          onClick={previewMode ? onComplete : undefined}
        >
          {/* Image background with transforms */}
          {hasImageTransform && (
            <div
              className="absolute inset-0 overflow-hidden pointer-events-none"
              style={{ zIndex: 0 }}
            >
              <div
                className="absolute inset-0"
                style={{
                  backgroundImage: `url(${background.value})`,
                  backgroundSize: 'cover',
                  backgroundPosition: `calc(50% + ${transform.x}%) calc(50% + ${transform.y}%)`,
                  transform: `scale(${transform.scale}) rotate(${transform.rotation}deg)`,
                  transformOrigin: 'center center',
                }}
              />
            </div>
          )}

          {/* Simple image background without transforms */}
          {background.type === 'image' && background.value && !hasImageTransform && (
            <div
              className="absolute inset-0 pointer-events-none"
              style={{
                backgroundImage: `url(${background.value})`,
                backgroundSize: 'cover',
                backgroundPosition: 'center',
                zIndex: 0,
              }}
            />
          )}

          {/* Overlay for images */}
          {background.type === 'image' && background.overlay_opacity && (
            <div
              className="absolute inset-0 bg-black pointer-events-none"
              style={{ opacity: background.overlay_opacity, zIndex: 1 }}
            />
          )}

          {/* Close button for preview mode */}
          {previewMode && (
            <button
              onClick={e => {
                e.stopPropagation();
                onComplete();
              }}
              className="absolute top-4 right-4 z-20 p-2 rounded-full bg-black/30 hover:bg-black/50 transition-colors"
              aria-label="Close preview"
            >
              <X className="w-6 h-6" style={{ color: theme.text_color }} />
            </button>
          )}

          {/* Content - positioned based on text transform */}
          {hasCustomTextPosition ? (
            // Custom positioned text - absolute to full screen
            <div className="absolute inset-0 z-10 pointer-events-none">
              <div
                className="absolute"
                style={{
                  left: `${textTransform.x}%`,
                  top: `${textTransform.y}%`,
                  transform: `translate(-50%, -50%) scale(${textTransform.scale}) rotate(${textTransform.rotation}deg)`,
                  transformOrigin: 'center center',
                }}
              >
                {renderAnimatedContent()}
              </div>
            </div>
          ) : (
            // Default centered layout
            <div className="flex-1 relative z-10 pointer-events-none">
              <div className="w-full h-full flex items-center justify-center">
                {renderAnimatedContent()}
              </div>
            </div>
          )}

          {/* Spacer when using custom position */}
          {hasCustomTextPosition && <div className="flex-1" />}

          {/* Bottom button */}
          <div className="relative z-10 pb-12 flex justify-center">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: animation.duration_ms / 1000 + 0.3 }}
            >
              <Button
                onClick={e => {
                  e.stopPropagation();
                  onComplete();
                }}
                size="lg"
                className="text-lg px-8 py-6 rounded-full shadow-lg hover:shadow-xl transition-shadow bg-white/90 hover:bg-white text-gray-800 border-0"
              >
                {previewMode ? 'Close Preview' : 'Open Invitation'}
              </Button>
            </motion.div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function getAnimationWrapper(preset: AnimationPreset) {
  switch (preset) {
    case 'fade_in':
      return FadeIn;
    case 'typewriter':
      return Typewriter;
    case 'slide_up':
      return SlideUp;
    case 'confetti_pop':
      return ConfettiPop;
    case 'bounce_in':
      return BounceIn;
    case 'sparkle':
      return Sparkle;
    default:
      return FadeIn;
  }
}
