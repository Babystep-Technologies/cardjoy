import { useState, useEffect } from 'react';
import { GiphyFetch } from '@giphy/js-fetch-api';
import type { IGif } from '@giphy/js-types';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { X } from 'lucide-react';
import { motion } from 'framer-motion';

// GIPHY is an optional integration. Only construct the client when a key is
// configured — the SDK throws on an empty key, which would crash the page.
const GIPHY_API_KEY = import.meta.env.VITE_GIPHY_API_KEY as string | undefined;
const gf = GIPHY_API_KEY ? new GiphyFetch(GIPHY_API_KEY) : null;
interface GiphySearchProps {
  onSelect: (gifUrl: string) => void;
  onClose: () => void;
}

export default function GiphySearch({ onSelect, onClose }: GiphySearchProps) {
  const [query, setQuery] = useState('');
  const [gifs, setGifs] = useState<IGif[]>([]);

  useEffect(() => {
    if (!gf) return;
    const fetchGifs = async () => {
      try {
        const data =
          query.trim() === ''
            ? await gf.trending({ limit: 9 })
            : await gf.search(query, { limit: 9 });

        setGifs(data.data);
      } catch (error) {
        console.error('Error fetching GIFs:', error);
      }
    };

    fetchGifs();
  }, [query]);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
      className="fixed inset-0 z-50 flex items-center justify-center bg-background p-4"
    >
      <div className="relative w-full sm:max-w-[90vw] md:max-w-[80vw] lg:max-w-[70vw]">
        {/* Close Button */}
        <Button
          variant="outline"
          onClick={onClose}
          className="absolute top-4 right-4 z-10 px-4 py-2 rounded shadow"
        >
          <X className="w-5 h-5" />
        </Button>

        <Card className="h-screen sm:h-[90vh] max-h-screen sm:max-h-[90vh] overflow-hidden flex flex-col">
          <CardHeader className="shrink-0">
            <CardTitle>Search GIPHY</CardTitle>
          </CardHeader>
          <CardContent className="flex-1 flex flex-col px-4 overflow-hidden">
            <input
              type="text"
              placeholder="Search GIPHY..."
              value={query}
              onChange={e => setQuery(e.target.value)}
              className="w-full border border-gray-300 p-2 rounded mb-4"
            />

            <div className="flex-1 overflow-y-auto pr-2 grid gap-4 grid-cols-[repeat(auto-fit,minmax(200px,1fr))]">
              {!gf && (
                <p className="col-span-full text-sm text-muted-foreground py-8 text-center">
                  GIPHY search is not configured. Set <code>VITE_GIPHY_API_KEY</code> to enable it.
                </p>
              )}
              {gifs.map(gif => (
                <div
                  key={gif.id}
                  className="relative w-full h-[160px] sm:h-[200px] md:h-[240px] lg:h-[280px] overflow-hidden rounded-xl shadow-md"
                >
                  <img
                    src={gif.images.fixed_height.url}
                    alt={gif.title}
                    loading="lazy"
                    className="w-full h-full object-cover cursor-pointer transition-transform duration-200 hover:scale-105"
                    onClick={() => onSelect(gif.images.fixed_height.url)}
                  />
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </motion.div>
  );
}
