import type { TemplateProps } from './types';

export function ClassicCentered({ text, textColor, fontFamily }: TemplateProps) {
  return (
    <div
      className="flex flex-col items-center justify-center text-center h-full px-6"
      style={{ color: textColor, fontFamily }}
    >
      <h1 className="text-4xl md:text-6xl font-bold mb-4">{text.title}</h1>
      {text.subtitle && <p className="text-xl md:text-2xl opacity-90">{text.subtitle}</p>}
    </div>
  );
}
