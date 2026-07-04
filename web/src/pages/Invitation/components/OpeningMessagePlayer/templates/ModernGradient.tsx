import type { TemplateProps } from './types';

export function ModernGradient({ text, textColor, fontFamily }: TemplateProps) {
  return (
    <div
      className="flex flex-col items-center justify-center text-center h-full px-6"
      style={{ color: textColor, fontFamily }}
    >
      <h1 className="text-5xl md:text-7xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-white via-white/90 to-white/70">
        {text.title}
      </h1>
      {text.subtitle && <p className="text-xl md:text-2xl opacity-80">{text.subtitle}</p>}
    </div>
  );
}
