import type { TemplateId } from '@/types/openingMessage';
import { TEMPLATE_LIST } from '@/config/openingMessage';
import { cn } from '@/lib/utils';

interface TemplateSelectorProps {
  value: TemplateId;
  onChange: (templateId: TemplateId) => void;
}

export function TemplateSelector({ value, onChange }: TemplateSelectorProps) {
  return (
    <div className="space-y-3">
      <label className="text-sm font-medium text-gray-700">Layout</label>
      <div className="grid grid-cols-2 gap-3">
        {TEMPLATE_LIST.map(template => (
          <button
            key={template.id}
            type="button"
            onClick={() => onChange(template.id)}
            className={cn(
              'p-4 rounded-xl border-2 transition-all text-left',
              value === template.id
                ? 'border-purple-500 bg-purple-50 shadow-md'
                : 'border-gray-200 hover:border-gray-300 bg-white'
            )}
          >
            <div className="font-medium text-sm">{template.name}</div>
            <div className="text-xs text-gray-500 mt-1">{template.description}</div>
          </button>
        ))}
      </div>
    </div>
  );
}
