import type { TemplateProps } from './types';

export function ElegantSplit({ text, textColor, fontFamily }: TemplateProps) {
  return (
    <div
      className="flex flex-col items-center justify-center text-center h-full gap-8 px-6"
      style={{ color: textColor, fontFamily }}
    >
      <h1 className="text-5xl md:text-7xl font-light tracking-wider">{text.title}</h1>
      {text.subtitle && (
        <p className="text-lg md:text-xl tracking-widest uppercase opacity-70">{text.subtitle}</p>
      )}
    </div>
  );
}
