/**
 * The holiday card editor: a left rail of controls, a large centred preview, and
 * a front/back toggle.
 *
 * This component owns the working copy of the design document and nothing else —
 * loading, saving, and photo mutations belong to the page above it. Keeping the
 * document in one place is what makes the autosave contract work: the API
 * replaces `design_config` wholesale, so exactly one thing may hold it.
 *
 * The preview scale is measured from the available space rather than fixed, so
 * the same honest geometry fills a laptop and still fits a tablet.
 */
import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Image as ImageIcon, LayoutGrid, Smile, Type } from 'lucide-react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { fitScale } from '../geometry';
import { clearSticker, remapDesign, setPhotoPlacement, setSticker, stickerIn } from '../design';
import type {
  DesignConfig,
  EditorOptions,
  HolidayCard,
  HolidayCardPhoto,
  HolidayCardTemplate,
  PanelName,
  Sticker,
} from '../types';
import { PanelPreview, type Selection } from './PanelPreview';
import { PanelToggle } from './PanelToggle';
import { TemplatePicker } from './TemplatePicker';
import { PhotoLibrary } from './PhotoLibrary';
import { PhotoControls } from './PhotoControls';
import { TextControls } from './TextControls';
import { StickerPicker } from './StickerPicker';

interface EditorProps {
  card: HolidayCard;
  template: HolidayCardTemplate;
  templates: HolidayCardTemplate[];
  stickers: Sticker[];
  options: EditorOptions;
  config: DesignConfig;
  onConfigChange: (next: DesignConfig) => void;
  onTemplateChange: (template: HolidayCardTemplate, next: DesignConfig, dropped: string[]) => void;
  onPhotoUploaded: (photo: HolidayCardPhoto) => void;
  onPhotoDeleted: (blobId: string) => void;
  deletingBlobId: string | null;
}

export const Editor: React.FC<EditorProps> = ({
  card,
  template,
  templates,
  stickers,
  options,
  config,
  onConfigChange,
  onTemplateChange,
  onPhotoUploaded,
  onPhotoDeleted,
  deletingBlobId,
}) => {
  const [panel, setPanel] = useState<PanelName>('front');
  const [selection, setSelection] = useState<Selection>(null);
  const [tab, setTab] = useState('photos');
  // Natural pixel size per blob, populated as images load. Keyed by blob id
  // rather than by slot, so the same photo in two slots is measured once.
  const [naturalSizes, setNaturalSizes] = useState<
    Record<string, { width: number; height: number }>
  >({});

  const stageRef = useRef<HTMLDivElement>(null);
  const [stage, setStage] = useState({ width: 0, height: 0 });

  // Measured rather than assumed: the rail is a fixed width but the window is
  // not, and the preview must never overflow its column.
  useLayoutEffect(() => {
    const element = stageRef.current;
    if (!element) return;

    const observer = new ResizeObserver(entries => {
      const box = entries[0]?.contentRect;
      if (box) setStage({ width: box.width, height: box.height });
    });
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  const scale = useMemo(
    () =>
      fitScale(template, {
        width: Math.max(stage.width - 32, 1),
        height: Math.max(stage.height - 32, 1),
      }),
    [template, stage.width, stage.height]
  );

  // A selection is a slot id on one panel, so it cannot survive a switch to the
  // other side or a change of layout.
  useEffect(() => setSelection(null), [panel, template.id]);

  // Selecting something on the card brings its controls forward — otherwise the
  // user clicks a photo slot and the rail is still showing the sticker list.
  useEffect(() => {
    if (selection?.kind === 'photo') setTab('photos');
    if (selection?.kind === 'text') setTab('text');
    if (selection?.kind === 'sticker') setTab('stickers');
  }, [selection]);

  const panelSpec = template[panel];
  const selectedPhotoSlot =
    selection?.kind === 'photo'
      ? panelSpec.photoSlots.find(slot => slot.id === selection.id)
      : undefined;
  const selectedTextRegion =
    selection?.kind === 'text'
      ? panelSpec.textRegions.find(region => region.id === selection.id)
      : undefined;
  const selectedStickerRegionId = selection?.kind === 'sticker' ? selection.id : null;

  const sameSizeTemplates = templates.filter(candidate => candidate.size === card.size);

  const handleTemplateSelect = (next: HolidayCardTemplate) => {
    if (next.id === template.id) return;

    const { config: remapped, dropped } = remapDesign(config, template, next);
    onTemplateChange(next, remapped, dropped);
  };

  const handlePlacePhoto = (blobId: string) => {
    if (!selectedPhotoSlot) return;

    // A fresh placement starts centred at 1×; the user reframes from there.
    onConfigChange(
      setPhotoPlacement(config, panel, selectedPhotoSlot.id, {
        blob_id: blobId,
        pan_x: 0,
        pan_y: 0,
        zoom: 1,
      })
    );
  };

  return (
    <div className="flex flex-1 flex-col-reverse overflow-hidden lg:flex-row">
      {/* ------------------------------- controls ------------------------------- */}
      <aside className="w-full shrink-0 overflow-y-auto border-t bg-white lg:w-96 lg:border-r lg:border-t-0">
        <div className="p-4">
          <Tabs value={tab} onValueChange={setTab}>
            <TabsList className="mb-4 grid w-full grid-cols-4">
              <TabsTrigger value="layout" title="Layout">
                <LayoutGrid className="h-4 w-4" />
              </TabsTrigger>
              <TabsTrigger value="photos" title="Photos">
                <ImageIcon className="h-4 w-4" />
              </TabsTrigger>
              <TabsTrigger value="text" title="Text">
                <Type className="h-4 w-4" />
              </TabsTrigger>
              <TabsTrigger value="stickers" title="Stickers">
                <Smile className="h-4 w-4" />
              </TabsTrigger>
            </TabsList>

            <TabsContent value="layout" className="mt-0">
              <p className="mb-3 text-sm text-gray-600">
                Your photos and words move to the new layout. Anything the new layout has no room
                for is called out before it goes.
              </p>
              <TemplatePicker
                templates={sameSizeTemplates}
                selectedId={template.id}
                panel={panel}
                config={config}
                options={options}
                photos={card.photos}
                stickers={stickers}
                onSelect={handleTemplateSelect}
              />
            </TabsContent>

            <TabsContent value="photos" className="mt-0 space-y-5">
              {selectedPhotoSlot && (
                <PhotoControls
                  slot={selectedPhotoSlot}
                  panel={panel}
                  config={config}
                  options={options}
                  naturalSize={
                    naturalSizes[
                      String(config[panel]?.photos?.[selectedPhotoSlot.id]?.blob_id ?? '')
                    ]
                  }
                  onChange={onConfigChange}
                />
              )}
              {!selectedPhotoSlot && panelSpec.photoSlots.length > 0 && (
                <p className="text-sm text-gray-500">
                  Pick a photo slot on the card to fill or reframe it.
                </p>
              )}
              {panelSpec.photoSlots.length === 0 && (
                <p className="text-sm text-gray-500">
                  This layout keeps the {panel} free of photos. Switch sides to place one.
                </p>
              )}
              <PhotoLibrary
                externalId={card.externalId}
                photos={card.photos}
                options={options}
                targetSlotId={selectedPhotoSlot?.id ?? null}
                onPlace={handlePlacePhoto}
                onUploaded={onPhotoUploaded}
                onDelete={onPhotoDeleted}
                deletingBlobId={deletingBlobId}
              />
            </TabsContent>

            <TabsContent value="text" className="mt-0">
              {selectedTextRegion ? (
                <TextControls
                  region={selectedTextRegion}
                  panel={panel}
                  panelBackground={panelSpec.background}
                  config={config}
                  options={options}
                  onChange={onConfigChange}
                />
              ) : (
                <p className="text-sm text-gray-500">
                  Click any text on the card to write in it and change how it looks.
                </p>
              )}
            </TabsContent>

            <TabsContent value="stickers" className="mt-0">
              <StickerPicker
                stickers={stickers}
                regionId={selectedStickerRegionId}
                selectedStickerId={
                  selectedStickerRegionId
                    ? stickerIn(config, panel, selectedStickerRegionId)?.sticker_id
                    : undefined
                }
                onSelect={stickerId =>
                  selectedStickerRegionId &&
                  onConfigChange(setSticker(config, panel, selectedStickerRegionId, stickerId))
                }
                onClear={() =>
                  selectedStickerRegionId &&
                  onConfigChange(clearSticker(config, panel, selectedStickerRegionId))
                }
              />
            </TabsContent>
          </Tabs>
        </div>
      </aside>

      {/* -------------------------------- preview -------------------------------- */}
      <section className="flex flex-1 flex-col overflow-hidden bg-gradient-to-br from-gray-100 to-gray-200">
        <div className="flex items-center justify-between gap-3 px-4 py-3">
          <PanelToggle value={panel} onChange={setPanel} />
          <span className="text-xs text-gray-500">
            {template.widthInches}″ × {template.heightInches}″ · dashed line is the safe margin
          </span>
        </div>

        <div ref={stageRef} className="flex flex-1 items-center justify-center overflow-auto p-4">
          {stage.width > 0 && (
            <PanelPreview
              template={template}
              panel={panel}
              config={config}
              options={options}
              photos={card.photos}
              stickers={stickers}
              scale={scale}
              interactive
              showGuides
              selection={selection}
              onSelect={setSelection}
              onChange={onConfigChange}
              naturalSizes={naturalSizes}
              onPhotoLoad={(blobId, size) =>
                setNaturalSizes(current =>
                  current[blobId]?.width === size.width && current[blobId]?.height === size.height
                    ? current
                    : { ...current, [blobId]: size }
                )
              }
            />
          )}
        </div>
      </section>
    </div>
  );
};
