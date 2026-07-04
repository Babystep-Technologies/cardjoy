import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import type { OpeningMessageConfig, ImageTransform, TextTransform } from '@/types/openingMessage';
import { DEFAULT_OPENING_MESSAGE_CONFIG } from '@/types/openingMessage';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { ArrowLeft, Play, Check, Smartphone } from 'lucide-react';
import { TemplateSelector } from './TemplateSelector';
import { TextEditor } from './TextEditor';
import { ThemeSelector } from './ThemeSelector';
import { BackgroundSelector } from './BackgroundSelector';
import { AnimationSelector } from './AnimationSelector';
import { AnimatedPreviewPane } from './AnimatedPreviewPane';
import { OpeningMessagePlayer } from '../OpeningMessagePlayer';

interface OpeningMessageEditorProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  value: OpeningMessageConfig | null;
  onChange: (config: OpeningMessageConfig) => void;
}

export function OpeningMessageEditor({
  open,
  onOpenChange,
  value,
  onChange,
}: OpeningMessageEditorProps) {
  // Local state for editing - initialize with value or default
  const [config, setConfig] = useState<OpeningMessageConfig>(
    value || DEFAULT_OPENING_MESSAGE_CONFIG
  );
  const [showPreview, setShowPreview] = useState(false);
  const [animationKey, setAnimationKey] = useState(0);
  const [isHorizontal, setIsHorizontal] = useState(false);

  // Reset local state when editor opens
  useEffect(() => {
    if (open) {
      setConfig(value || DEFAULT_OPENING_MESSAGE_CONFIG);
      setAnimationKey(prev => prev + 1);
    }
  }, [open, value]);

  // Trigger animation replay when animation settings change
  useEffect(() => {
    setAnimationKey(prev => prev + 1);
  }, [config.animation?.preset, config.animation?.duration_ms]);

  const handleSave = () => {
    onChange(config);
    onOpenChange(false);
  };

  const handleBack = () => {
    onOpenChange(false);
  };

  const handlePreview = () => {
    setShowPreview(true);
  };

  const handlePreviewComplete = () => {
    // Return to editor instead of closing completely
    setShowPreview(false);
  };

  const handleReplay = () => {
    setAnimationKey(prev => prev + 1);
  };

  const handleTransformChange = (transform: ImageTransform) => {
    setConfig({
      ...config,
      background: {
        ...config.background!,
        image_transform: transform,
      },
    });
  };

  const handleTextTransformChange = (transform: TextTransform) => {
    setConfig({
      ...config,
      text: {
        ...config.text,
        transform,
      },
    });
  };

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          className="fixed inset-0 z-50 bg-gray-50 flex flex-col"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
        >
          {/* Header */}
          <div className="flex-shrink-0 bg-white border-b px-4 py-3 flex items-center justify-between">
            <button
              onClick={handleBack}
              className="flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors"
            >
              <ArrowLeft className="w-5 h-5" />
              <span className="font-medium">Back</span>
            </button>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={handlePreview}
              className="gap-2"
            >
              <Play className="w-4 h-4" />
              Full Screen Preview
            </Button>
            <Button
              onClick={handleSave}
              size="sm"
              className="bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 gap-2"
            >
              <Check className="w-4 h-4" />
              Save
            </Button>
          </div>

          {/* Main Content */}
          <div className="flex-1 overflow-hidden flex flex-col lg:flex-row">
            {/* Preview Section */}
            <div className="flex-1 flex flex-col items-center justify-center p-2 bg-gradient-to-br from-gray-100 to-gray-200">
              {/* Orientation Toggle */}
              <div className="mb-2 flex items-center gap-1">
                <button
                  type="button"
                  onClick={() => setIsHorizontal(false)}
                  className={`p-1 rounded transition-colors ${
                    !isHorizontal
                      ? 'bg-white shadow text-purple-600'
                      : 'bg-transparent text-gray-400 hover:text-gray-600'
                  }`}
                  title="Vertical (Portrait)"
                >
                  <Smartphone className="w-4 h-4" />
                </button>
                <button
                  type="button"
                  onClick={() => setIsHorizontal(true)}
                  className={`p-1 rounded transition-colors ${
                    isHorizontal
                      ? 'bg-white shadow text-purple-600'
                      : 'bg-transparent text-gray-400 hover:text-gray-600'
                  }`}
                  title="Horizontal (Landscape)"
                >
                  <Smartphone className="w-4 h-4 rotate-90" />
                </button>
              </div>

              <div
                className={
                  isHorizontal
                    ? 'w-full max-w-[95%] lg:max-w-[600px]'
                    : 'w-[55%] max-w-[280px] lg:w-[45%] lg:max-w-[350px]'
                }
              >
                <AnimatedPreviewPane
                  config={config}
                  animationKey={animationKey}
                  onReplay={handleReplay}
                  onTransformChange={handleTransformChange}
                  onTextTransformChange={handleTextTransformChange}
                  isHorizontal={isHorizontal}
                />
              </div>
            </div>

            {/* Editor Panel */}
            <div className="flex-shrink-0 lg:w-96 bg-white border-t lg:border-t-0 lg:border-l overflow-y-auto">
              <div className="p-4 lg:p-6">
                <Tabs defaultValue="text" className="w-full">
                  <TabsList className="grid w-full grid-cols-4 mb-4">
                    <TabsTrigger value="text">Text</TabsTrigger>
                    <TabsTrigger value="layout">Layout</TabsTrigger>
                    <TabsTrigger value="style">Style</TabsTrigger>
                    <TabsTrigger value="anim">Anim</TabsTrigger>
                  </TabsList>

                  <TabsContent value="text" className="mt-0">
                    <TextEditor
                      value={config.text}
                      onChange={text => setConfig({ ...config, text })}
                    />
                  </TabsContent>

                  <TabsContent value="layout" className="mt-0">
                    <TemplateSelector
                      value={config.template_id}
                      onChange={template_id => setConfig({ ...config, template_id })}
                    />
                  </TabsContent>

                  <TabsContent value="style" className="mt-0 space-y-6">
                    <ThemeSelector
                      value={config.theme || { font: 'poppins', text_color: '#FFFFFF' }}
                      onChange={theme => setConfig({ ...config, theme })}
                    />
                    <BackgroundSelector
                      value={
                        config.background || {
                          type: 'gradient',
                          value: 'from-purple-400 via-pink-400 to-blue-400',
                          overlay_opacity: 0,
                        }
                      }
                      onChange={background => setConfig({ ...config, background })}
                    />
                  </TabsContent>

                  <TabsContent value="anim" className="mt-0">
                    <AnimationSelector
                      preset={config.animation?.preset || 'fade_in'}
                      durationMs={config.animation?.duration_ms || 1800}
                      onPresetChange={preset =>
                        setConfig({
                          ...config,
                          animation: {
                            ...config.animation,
                            preset,
                            duration_ms: config.animation?.duration_ms || 1800,
                          },
                        })
                      }
                      onDurationChange={duration_ms =>
                        setConfig({
                          ...config,
                          animation: {
                            ...config.animation,
                            preset: config.animation?.preset || 'fade_in',
                            duration_ms,
                          },
                        })
                      }
                    />
                  </TabsContent>
                </Tabs>
              </div>
            </div>
          </div>

          {/* Full-screen animation preview */}
          {showPreview && (
            <OpeningMessagePlayer
              config={config}
              onComplete={handlePreviewComplete}
              isVisible={showPreview}
              previewMode={true}
            />
          )}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
