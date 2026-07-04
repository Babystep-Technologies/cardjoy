import type { TemplateProps } from './types';

export function MinimalBottom({ text, textColor, fontFamily }: TemplateProps) {
  return (
    <div
      className="flex flex-col items-center justify-end text-center h-full pb-24 px-6"
      style={{ color: textColor, fontFamily }}
    >
      <h1 className="text-3xl md:text-5xl font-medium mb-3">{text.title}</h1>
      {text.subtitle && <p className="text-base md:text-lg opacity-75">{text.subtitle}</p>}
    </div>
  );
}
