import { useState, useRef, useCallback } from 'react';

export interface PlacePrediction {
  placeId: string;
  description: string;
  mainText: string;
  secondaryText?: string;
}

interface UseAddressAutocompleteOptions {
  debounceMs?: number;
  minChars?: number;
  limit?: number;
}

interface UseAddressAutocompleteResult {
  predictions: PlacePrediction[];
  isLoading: boolean;
  error: string | null;
  getPredictions: (input: string) => void;
  clearPredictions: () => void;
  resetSession: () => void;
}

interface NominatimAddress {
  house_number?: string;
  road?: string;
  neighbourhood?: string;
  suburb?: string;
  city?: string;
  town?: string;
  village?: string;
  county?: string;
  state?: string;
  postcode?: string;
  country?: string;
  country_code?: string;
}

interface NominatimResult {
  place_id: number;
  osm_type: string;
  osm_id: number;
  display_name: string;
  address: NominatimAddress;
}

function formatNominatimResult(result: NominatimResult): PlacePrediction {
  const addr = result.address;

  // Build main text (street address)
  let mainText = '';
  if (addr.house_number && addr.road) {
    mainText = `${addr.house_number} ${addr.road}`;
  } else if (addr.road) {
    mainText = addr.road;
  } else if (addr.neighbourhood) {
    mainText = addr.neighbourhood;
  }

  // Get city (could be city, town, or village)
  const city = addr.city || addr.town || addr.village || '';

  // Build secondary text (city, state, zip)
  const secondaryParts: string[] = [];
  if (city) secondaryParts.push(city);
  if (addr.state) secondaryParts.push(addr.state);
  if (addr.postcode) secondaryParts.push(addr.postcode);
  // Only show country for non-US addresses
  if (addr.country && addr.country_code !== 'us') {
    secondaryParts.push(addr.country);
  }

  const secondaryText = secondaryParts.join(', ');

  // Use display_name as the full description, but clean it up
  // Remove ", United States" from the end for US addresses
  let description = result.display_name;
  if (addr.country_code === 'us') {
    description = description.replace(/, United States$/, '');
  }

  return {
    placeId: `${result.osm_type}-${result.osm_id}`,
    description,
    mainText: mainText || city || result.display_name.split(',')[0],
    secondaryText: secondaryText || undefined,
  };
}

export function useAddressAutocomplete(
  options: UseAddressAutocompleteOptions = {}
): UseAddressAutocompleteResult {
  const { debounceMs = 400, minChars = 3, limit = 5 } = options;

  const [predictions, setPredictions] = useState<PlacePrediction[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const debounceTimerRef = useRef<NodeJS.Timeout | null>(null);
  const abortControllerRef = useRef<AbortController | null>(null);

  const resetSession = useCallback(() => {
    // No-op (kept for API compatibility)
  }, []);

  const clearPredictions = useCallback(() => {
    setPredictions([]);
  }, []);

  const getPredictions = useCallback(
    (input: string) => {
      // Clear any pending request
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
      }

      // Abort any in-flight request
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }

      // Clear predictions if input is too short
      if (!input || input.length < minChars) {
        setPredictions([]);
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      setError(null);

      debounceTimerRef.current = setTimeout(async () => {
        abortControllerRef.current = new AbortController();

        try {
          const params = new URLSearchParams({
            q: input,
            format: 'json',
            addressdetails: '1',
            limit: limit.toString(),
          });

          const response = await fetch(`https://nominatim.openstreetmap.org/search?${params}`, {
            signal: abortControllerRef.current.signal,
            headers: {
              'User-Agent': 'CardjoyApp/1.0 (https://cardjoy.app)',
            },
          });

          if (!response.ok) {
            throw new Error('Failed to fetch address suggestions');
          }

          const data: NominatimResult[] = await response.json();

          const formattedPredictions = data.map(formatNominatimResult);
          setPredictions(formattedPredictions);
        } catch (err) {
          if (err instanceof Error && err.name === 'AbortError') {
            // Request was aborted, ignore
            return;
          }
          setError(err instanceof Error ? err.message : 'Failed to fetch suggestions');
          setPredictions([]);
        } finally {
          setIsLoading(false);
        }
      }, debounceMs);
    },
    [debounceMs, minChars, limit]
  );

  return {
    predictions,
    isLoading,
    error,
    getPredictions,
    clearPredictions,
    resetSession,
  };
}
