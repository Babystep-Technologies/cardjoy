import type { OpeningMessageConfig } from '@/types/openingMessage';
import { TEMPLATE_COMPONENTS } from '../OpeningMessagePlayer/templates';

interface PreviewPaneProps {
  config: OpeningMessageConfig;
}

export function PreviewPane({ config }: PreviewPaneProps) {
  const {
    template_id,
    text,
    theme = { font: 'poppins', text_color: '#FFFFFF' },
    background = {
      type: 'gradient',
      value: 'from-purple-400 via-pink-400 to-blue-400',
      overlay_opacity: 0,
    },
  } = config;

  const TemplateComponent = TEMPLATE_COMPONENTS[template_id];

  const getBackgroundStyle = () => {
    if (background.type === 'color') {
      return { backgroundColor: background.value };
    }
    if (background.type === 'image') {
      return {
        backgroundImage: `url(${background.value})`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
      };
    }
    return {};
  };

  const getBackgroundClassName = () => {
    if (background.type === 'gradient') {
      return `bg-gradient-to-br ${background.value}`;
    }
    return '';
  };

  return (
    <div
      className={`relative w-full aspect-[9/16] rounded-2xl overflow-hidden shadow-lg ${getBackgroundClassName()}`}
      style={getBackgroundStyle()}
    >
      {/* Overlay for images */}
      {background.type === 'image' && background.overlay_opacity && (
        <div
          className="absolute inset-0 bg-black"
          style={{ opacity: background.overlay_opacity }}
        />
      )}

      {/* Content - scaled down preview */}
      <div className="absolute inset-0 transform scale-[0.35] origin-center">
        <div className="w-[285%] h-[285%] -translate-x-[32.5%] -translate-y-[32.5%]">
          <TemplateComponent text={text} textColor={theme.text_color} />
        </div>
      </div>

      {/* Preview label */}
      <div className="absolute bottom-2 left-0 right-0 text-center">
        <span className="text-xs text-white/70 bg-black/30 px-2 py-1 rounded">Preview</span>
      </div>
    </div>
  );
}
