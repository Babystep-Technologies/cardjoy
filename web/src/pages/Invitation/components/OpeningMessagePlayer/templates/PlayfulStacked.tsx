import type { TemplateProps } from './types';

export function PlayfulStacked({ text, textColor, fontFamily }: TemplateProps) {
  return (
    <div
      className="flex flex-col items-center justify-center text-center h-full px-6"
      style={{ color: textColor, fontFamily }}
    >
      <h1 className="text-6xl md:text-8xl font-extrabold mb-2 -rotate-2">{text.title}</h1>
      {text.subtitle && <p className="text-2xl md:text-3xl rotate-1 opacity-90">{text.subtitle}</p>}
    </div>
  );
}
