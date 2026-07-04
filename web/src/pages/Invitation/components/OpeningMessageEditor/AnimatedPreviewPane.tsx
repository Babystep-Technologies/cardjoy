import { useState, useRef } from 'react';
import { motion } from 'motion/react';
import type {
  OpeningMessageConfig,
  AnimationPreset,
  ImageTransform,
  TextTransform,
} from '@/types/openingMessage';
import { FONTS } from '@/config/openingMessage/themes';
import {
  FadeIn,
  Typewriter,
  TypewriterText,
  SlideUp,
  ConfettiPop,
  BounceIn,
  Sparkle,
} from '../OpeningMessagePlayer/animations';
import { RefreshCw, Move, RotateCw } from 'lucide-react';

interface AnimatedPreviewPaneProps {
  config: OpeningMessageConfig;
  animationKey: number;
  onReplay: () => void;
  onTransformChange?: (transform: ImageTransform) => void;
  onTextTransformChange?: (transform: TextTransform) => void;
  isHorizontal?: boolean;
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

// Calculate safe position bounds based on scale to prevent text from going off screen
// At scale 1.0: allow 15-85%
// At scale 2.0: allow 35-65%
// This ensures text stays visible regardless of device
function getSafePositionBounds(scale: number): { min: number; max: number } {
  const baseMin = 15;
  const baseMax = 85;
  // Increase constraint as scale increases
  const scaleOffset = (scale - 1) * 20; // 20% more constrained per 1x scale increase
  return {
    min: Math.min(45, baseMin + scaleOffset),
    max: Math.max(55, baseMax - scaleOffset),
  };
}

function clampPosition(value: number, scale: number): number {
  const bounds = getSafePositionBounds(scale);
  return Math.max(bounds.min, Math.min(bounds.max, value));
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

type DragMode = 'none' | 'move' | 'resize' | 'rotate';

export function AnimatedPreviewPane({
  config,
  animationKey,
  onReplay,
  onTransformChange,
  onTextTransformChange,
  isHorizontal = false,
}: AnimatedPreviewPaneProps) {
  const {
    text,
    theme = { font: 'poppins', text_color: '#FFFFFF' },
    background = {
      type: 'gradient',
      value: 'from-purple-400 via-pink-400 to-blue-400',
      overlay_opacity: 0,
    },
    animation = { preset: 'fade_in', duration_ms: 1800 },
  } = config;

  const transform = background.image_transform || DEFAULT_TRANSFORM;
  const textTransform = text.transform || DEFAULT_TEXT_TRANSFORM;
  const isImageBackground = background.type === 'image' && background.value;
  const fontFamily = FONTS[theme.font]?.fontFamily;

  const containerRef = useRef<HTMLDivElement>(null);
  const textRef = useRef<HTMLDivElement>(null);

  // Drag state
  const [dragMode, setDragMode] = useState<DragMode>('none');
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [isTextSelected, setIsTextSelected] = useState(false);

  // Live transform state during drag
  const [liveTextTransform, setLiveTextTransform] = useState<TextTransform | null>(null);
  const [liveImageTransform, setLiveImageTransform] = useState<ImageTransform | null>(null);

  const currentTextTransform = liveTextTransform || textTransform;
  const currentImageTransform = liveImageTransform || transform;

  const getBackgroundStyle = (): React.CSSProperties => {
    if (background.type === 'color') {
      return { backgroundColor: background.value };
    }
    return {};
  };

  const getBackgroundClassName = () => {
    if (background.type === 'gradient') {
      return `bg-gradient-to-br ${background.value}`;
    }
    return '';
  };

  // Image drag handlers
  const handleImagePointerDown = (e: React.PointerEvent) => {
    if (!isImageBackground || !onTransformChange || isTextSelected) return;

    e.preventDefault();
    setDragMode('move');
    setDragStart({ x: e.clientX, y: e.clientY });
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handleImagePointerMove = (e: React.PointerEvent) => {
    if (dragMode !== 'move' || !containerRef.current || !isImageBackground) return;

    const rect = containerRef.current.getBoundingClientRect();
    const deltaX = -((e.clientX - dragStart.x) / rect.width) * 100;
    const deltaY = -((e.clientY - dragStart.y) / rect.height) * 100;

    const newX = Math.max(-50, Math.min(50, transform.x + deltaX));
    const newY = Math.max(-50, Math.min(50, transform.y + deltaY));

    setLiveImageTransform({ ...transform, x: newX, y: newY });
  };

  const handleImagePointerUp = (e: React.PointerEvent) => {
    if (dragMode !== 'move' || !onTransformChange || !liveImageTransform) {
      setDragMode('none');
      return;
    }

    (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
    onTransformChange(liveImageTransform);
    setLiveImageTransform(null);
    setDragMode('none');
  };

  // Text interaction handlers
  const handleTextPointerDown = (e: React.PointerEvent) => {
    if (!onTextTransformChange) return;

    e.preventDefault();
    e.stopPropagation();
    setIsTextSelected(true);
    setDragMode('move');
    setDragStart({ x: e.clientX, y: e.clientY });
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handleTextPointerMove = (e: React.PointerEvent) => {
    if (dragMode !== 'move' || !containerRef.current || !isTextSelected) return;

    const rect = containerRef.current.getBoundingClientRect();
    const deltaX = ((e.clientX - dragStart.x) / rect.width) * 100;
    const deltaY = ((e.clientY - dragStart.y) / rect.height) * 100;

    const newX = clampPosition(textTransform.x + deltaX, textTransform.scale);
    const newY = clampPosition(textTransform.y + deltaY, textTransform.scale);

    setLiveTextTransform({ ...textTransform, x: newX, y: newY });
  };

  const handleTextPointerUp = (e: React.PointerEvent) => {
    if (!onTextTransformChange || !liveTextTransform) {
      setDragMode('none');
      return;
    }

    (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
    // Ensure final position is clamped
    const clampedTransform = {
      ...liveTextTransform,
      x: clampPosition(liveTextTransform.x, liveTextTransform.scale),
      y: clampPosition(liveTextTransform.y, liveTextTransform.scale),
    };
    onTextTransformChange(clampedTransform);
    setLiveTextTransform(null);
    setDragMode('none');
  };

  // Resize handler
  const handleResizePointerDown = (e: React.PointerEvent) => {
    if (!onTextTransformChange) return;

    e.preventDefault();
    e.stopPropagation();
    setDragMode('resize');
    setDragStart({ x: e.clientX, y: e.clientY });
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handleResizePointerMove = (e: React.PointerEvent) => {
    if (dragMode !== 'resize' || !containerRef.current) return;

    const deltaY = e.clientY - dragStart.y;
    // Larger delta = smaller scale (dragging down makes smaller)
    const scaleDelta = -deltaY / 100;
    const newScale = Math.max(0.3, Math.min(2.5, textTransform.scale + scaleDelta));

    // Re-clamp position based on new scale
    const newX = clampPosition(textTransform.x, newScale);
    const newY = clampPosition(textTransform.y, newScale);

    setLiveTextTransform({ ...textTransform, scale: newScale, x: newX, y: newY });
  };

  const handleResizePointerUp = (e: React.PointerEvent) => {
    if (!onTextTransformChange || !liveTextTransform) {
      setDragMode('none');
      return;
    }

    (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
    // Ensure position is safe for the new scale
    const clampedTransform = {
      ...liveTextTransform,
      x: clampPosition(liveTextTransform.x, liveTextTransform.scale),
      y: clampPosition(liveTextTransform.y, liveTextTransform.scale),
    };
    onTextTransformChange(clampedTransform);
    setLiveTextTransform(null);
    setDragMode('none');
  };

  // Rotate handler
  const handleRotatePointerDown = (e: React.PointerEvent) => {
    if (!onTextTransformChange || !containerRef.current) return;

    e.preventDefault();
    e.stopPropagation();
    setDragMode('rotate');
    setDragStart({ x: e.clientX, y: e.clientY });
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handleRotatePointerMove = (e: React.PointerEvent) => {
    if (dragMode !== 'rotate' || !containerRef.current || !textRef.current) return;

    const rect = containerRef.current.getBoundingClientRect();
    const centerX = rect.left + (currentTextTransform.x / 100) * rect.width;
    const centerY = rect.top + (currentTextTransform.y / 100) * rect.height;

    // Calculate angle from center to current pointer position
    const angle = Math.atan2(e.clientY - centerY, e.clientX - centerX);
    const angleDeg = (angle * 180) / Math.PI + 90; // +90 to make 0 at top

    // Normalize to -180 to 180
    let rotation = angleDeg;
    if (rotation > 180) rotation -= 360;
    if (rotation < -180) rotation += 360;

    setLiveTextTransform({ ...textTransform, rotation: Math.round(rotation) });
  };

  const handleRotatePointerUp = (e: React.PointerEvent) => {
    if (!onTextTransformChange || !liveTextTransform) {
      setDragMode('none');
      return;
    }

    (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
    onTextTransformChange(liveTextTransform);
    setLiveTextTransform(null);
    setDragMode('none');
  };

  // Click outside to deselect
  const handleContainerClick = (e: React.MouseEvent) => {
    if (e.target === containerRef.current) {
      setIsTextSelected(false);
    }
  };

  const renderTextContent = () => {
    if (animation.preset === 'typewriter') {
      return (
        <div
          className="flex flex-col items-center justify-center text-center px-4"
          style={{ color: theme.text_color, fontFamily }}
        >
          <h1 className="text-lg font-bold leading-tight">
            <TypewriterText text={text.title} />
          </h1>
          {text.subtitle && (
            <p className="text-sm opacity-90 mt-1">
              <TypewriterText text={text.subtitle} />
            </p>
          )}
        </div>
      );
    }

    return (
      <div
        className="flex flex-col items-center justify-center text-center px-4"
        style={{ color: theme.text_color, fontFamily }}
      >
        <h1 className="text-lg font-bold leading-tight">{text.title}</h1>
        {text.subtitle && <p className="text-sm opacity-90 mt-1">{text.subtitle}</p>}
      </div>
    );
  };

  const AnimationWrapper = getAnimationWrapper(animation.preset);

  return (
    <div className="relative">
      {/* Main Preview Container */}
      <motion.div
        ref={containerRef}
        key={animationKey}
        className={`relative w-full rounded-2xl overflow-hidden shadow-lg ${getBackgroundClassName()} ${
          isHorizontal ? 'aspect-[16/9]' : 'aspect-[9/16]'
        }`}
        style={{
          ...getBackgroundStyle(),
          cursor: isImageBackground && !isTextSelected ? 'grab' : 'default',
          touchAction: 'none',
        }}
        onClick={handleContainerClick}
        onPointerDown={handleImagePointerDown}
        onPointerMove={handleImagePointerMove}
        onPointerUp={handleImagePointerUp}
        onPointerCancel={handleImagePointerUp}
      >
        {/* Image background with transforms */}
        {isImageBackground && (
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              backgroundImage: `url(${background.value})`,
              backgroundSize: 'cover',
              backgroundPosition: `calc(50% + ${currentImageTransform.x}%) calc(50% + ${currentImageTransform.y}%)`,
              transform: `scale(${currentImageTransform.scale}) rotate(${currentImageTransform.rotation}deg)`,
              transformOrigin: 'center center',
            }}
          />
        )}

        {/* Overlay for images */}
        {background.type === 'image' && background.overlay_opacity && (
          <div
            className="absolute inset-0 bg-black pointer-events-none"
            style={{ opacity: background.overlay_opacity }}
          />
        )}

        {/* Text content with transforms */}
        <div
          ref={textRef}
          className={`absolute ${isTextSelected ? 'ring-2 ring-white/50 ring-offset-2 ring-offset-transparent rounded-lg' : ''}`}
          style={{
            left: `${currentTextTransform.x}%`,
            top: `${currentTextTransform.y}%`,
            transform: `translate(-50%, -50%) scale(${currentTextTransform.scale}) rotate(${currentTextTransform.rotation}deg)`,
            cursor: onTextTransformChange
              ? dragMode === 'move' && isTextSelected
                ? 'grabbing'
                : 'grab'
              : 'default',
            zIndex: 10,
            padding: '8px',
          }}
          onPointerDown={handleTextPointerDown}
          onPointerMove={handleTextPointerMove}
          onPointerUp={handleTextPointerUp}
          onPointerCancel={handleTextPointerUp}
          onClick={e => {
            e.stopPropagation();
            setIsTextSelected(true);
          }}
        >
          <AnimationWrapper duration={animation.duration_ms}>
            {renderTextContent()}
          </AnimationWrapper>

          {/* Resize/Rotate handles - only show when selected */}
          {isTextSelected && onTextTransformChange && (
            <>
              {/* Rotate handle - top center */}
              <div
                className="absolute -top-8 left-1/2 -translate-x-1/2 w-6 h-6 bg-white rounded-full shadow-lg flex items-center justify-center cursor-crosshair border-2 border-purple-500 hover:bg-purple-50"
                style={{
                  transform: `translateX(-50%) rotate(${-currentTextTransform.rotation}deg)`,
                }}
                onPointerDown={handleRotatePointerDown}
                onPointerMove={handleRotatePointerMove}
                onPointerUp={handleRotatePointerUp}
                onPointerCancel={handleRotatePointerUp}
                title="Drag to rotate"
              >
                <RotateCw className="w-3 h-3 text-purple-600" />
              </div>

              {/* Connection line from rotate handle */}
              <div
                className="absolute -top-6 left-1/2 w-0.5 h-4 bg-white/50"
                style={{ transform: 'translateX(-50%)' }}
              />

              {/* Resize handle - bottom right corner */}
              <div
                className="absolute -bottom-2 -right-2 w-5 h-5 bg-white rounded-full shadow-lg cursor-nwse-resize border-2 border-purple-500 hover:bg-purple-50"
                style={{ transform: `rotate(${-currentTextTransform.rotation}deg)` }}
                onPointerDown={handleResizePointerDown}
                onPointerMove={handleResizePointerMove}
                onPointerUp={handleResizePointerUp}
                onPointerCancel={handleResizePointerUp}
                title="Drag to resize"
              >
                <div className="absolute inset-1 border-r-2 border-b-2 border-purple-500 rounded-br" />
              </div>
            </>
          )}
        </div>

        {/* Mode indicator */}
        {dragMode !== 'none' && (
          <div className="absolute top-2 left-1/2 -translate-x-1/2 z-20 pointer-events-none">
            <div className="bg-black/60 text-white px-3 py-1 rounded-full text-xs flex items-center gap-1">
              {dragMode === 'move' && !isTextSelected && <Move className="w-3 h-3" />}
              {dragMode === 'move' && isTextSelected && <Move className="w-3 h-3" />}
              {dragMode === 'resize' && 'Resizing'}
              {dragMode === 'rotate' && (
                <>
                  <RotateCw className="w-3 h-3" /> {Math.round(currentTextTransform.rotation)}°
                </>
              )}
              {dragMode === 'move' && (isTextSelected ? 'Moving text' : 'Moving image')}
            </div>
          </div>
        )}
      </motion.div>

      {/* Replay Button */}
      <button
        type="button"
        onClick={onReplay}
        className="absolute -bottom-2 -right-2 p-2 rounded-full bg-white shadow-md hover:shadow-lg transition-shadow border border-gray-200 hover:bg-gray-50"
        title="Replay animation"
      >
        <RefreshCw className="w-4 h-4 text-gray-600" />
      </button>

      {/* Hint */}
      {dragMode === 'none' && !isTextSelected && onTextTransformChange && (
        <div className="absolute bottom-2 left-0 right-0 text-center pointer-events-none">
          <span className="text-xs text-white/80 bg-black/40 px-2 py-1 rounded">
            Click text to edit position
          </span>
        </div>
      )}
    </div>
  );
}
