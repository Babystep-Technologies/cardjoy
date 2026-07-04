export interface GradientPreset {
  id: string;
  name: string;
  value: string;
  preview: string; // CSS gradient for preview thumbnail
}

export const GRADIENT_PRESETS: GradientPreset[] = [
  {
    id: 'sunset',
    name: 'Sunset',
    value: 'from-purple-400 via-pink-400 to-blue-400',
    preview: 'linear-gradient(135deg, #a855f7, #f472b6, #60a5fa)',
  },
  {
    id: 'ocean',
    name: 'Ocean',
    value: 'from-cyan-500 via-blue-500 to-indigo-500',
    preview: 'linear-gradient(135deg, #06b6d4, #3b82f6, #6366f1)',
  },
  {
    id: 'forest',
    name: 'Forest',
    value: 'from-green-400 via-emerald-500 to-teal-500',
    preview: 'linear-gradient(135deg, #4ade80, #10b981, #14b8a6)',
  },
  {
    id: 'rose_gold',
    name: 'Rose Gold',
    value: 'from-rose-300 via-pink-300 to-amber-200',
    preview: 'linear-gradient(135deg, #fda4af, #f9a8d4, #fde68a)',
  },
  {
    id: 'midnight',
    name: 'Midnight',
    value: 'from-slate-900 via-purple-900 to-slate-900',
    preview: 'linear-gradient(135deg, #0f172a, #581c87, #0f172a)',
  },
  {
    id: 'aurora',
    name: 'Aurora',
    value: 'from-violet-500 via-fuchsia-500 to-pink-500',
    preview: 'linear-gradient(135deg, #8b5cf6, #d946ef, #ec4899)',
  },
  {
    id: 'golden_hour',
    name: 'Golden Hour',
    value: 'from-amber-400 via-orange-400 to-red-400',
    preview: 'linear-gradient(135deg, #fbbf24, #fb923c, #f87171)',
  },
  {
    id: 'monochrome',
    name: 'Monochrome',
    value: 'from-gray-700 via-gray-800 to-gray-900',
    preview: 'linear-gradient(135deg, #374151, #1f2937, #111827)',
  },
];

export const SOLID_COLORS = [
  { id: 'white', name: 'White', value: '#FFFFFF' },
  { id: 'black', name: 'Black', value: '#000000' },
  { id: 'navy', name: 'Navy', value: '#1e3a5f' },
  { id: 'burgundy', name: 'Burgundy', value: '#722f37' },
  { id: 'forest_green', name: 'Forest Green', value: '#228b22' },
  { id: 'plum', name: 'Plum', value: '#673147' },
  { id: 'slate', name: 'Slate', value: '#475569' },
  { id: 'coral', name: 'Coral', value: '#ff7f50' },
];
