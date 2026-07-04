import type { TemplateProps } from './types';

export function BoldLeft({ text, textColor, fontFamily }: TemplateProps) {
  return (
    <div
      className="flex flex-col items-start justify-center text-left h-full px-8 md:px-16"
      style={{ color: textColor, fontFamily }}
    >
      <h1 className="text-5xl md:text-7xl font-black mb-4 leading-tight">{text.title}</h1>
      {text.subtitle && <p className="text-lg md:text-xl opacity-80">{text.subtitle}</p>}
    </div>
  );
}
