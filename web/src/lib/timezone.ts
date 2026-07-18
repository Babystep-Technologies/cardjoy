// Supported timezones in the app
export const SUPPORTED_TIMEZONES = [
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Anchorage',
  'Pacific/Honolulu',
  'Europe/London',
  'Europe/Paris',
  'Asia/Tokyo',
  'Asia/Shanghai',
  'Australia/Sydney',
  'UTC',
] as const;

export type SupportedTimezone = (typeof SUPPORTED_TIMEZONES)[number];

// Labelled options for a timezone <select>, in the same order/wording the
// invitation flow uses, so the two schedulers read consistently.
export const TIMEZONE_OPTIONS: { value: SupportedTimezone; label: string }[] = [
  { value: 'America/New_York', label: 'Eastern Time' },
  { value: 'America/Chicago', label: 'Central Time' },
  { value: 'America/Denver', label: 'Mountain Time' },
  { value: 'America/Los_Angeles', label: 'Pacific Time' },
  { value: 'America/Anchorage', label: 'Alaska Time' },
  { value: 'Pacific/Honolulu', label: 'Hawaii Time' },
  { value: 'Europe/London', label: 'London (GMT)' },
  { value: 'Europe/Paris', label: 'Central European Time' },
  { value: 'Asia/Tokyo', label: 'Tokyo' },
  { value: 'Asia/Shanghai', label: 'Beijing/Shanghai' },
  { value: 'Australia/Sydney', label: 'Sydney' },
  { value: 'UTC', label: 'UTC' },
];

// How far ahead of UTC `timeZone` is at `date`, in milliseconds (negative when
// behind UTC). Uses `Intl` formatting rather than a tz library.
function timezoneOffsetMs(timeZone: string, date: Date): number {
  const asZone = new Date(date.toLocaleString('en-US', { timeZone }));
  const asUtc = new Date(date.toLocaleString('en-US', { timeZone: 'UTC' }));
  return asZone.getTime() - asUtc.getTime();
}

/**
 * Converts a wall-clock date + time in a given IANA timezone to a UTC ISO
 * string. `date` is 'yyyy-MM-dd', `time` is 'HH:mm'. E.g. 2026-07-20 / 09:00 in
 * America/Los_Angeles → '2026-07-20T16:00:00.000Z'. The offset is measured at
 * the target instant, so it is correct year-round bar the ~1hr/year DST folds.
 */
export function zonedWallTimeToUtcISO(date: string, time: string, timeZone: string): string {
  // The Y-M-D H:M components read as if they were already UTC.
  const naiveUtc = new Date(`${date}T${time}:00Z`);
  const offset = timezoneOffsetMs(timeZone, naiveUtc);
  return new Date(naiveUtc.getTime() - offset).toISOString();
}

/**
 * Splits a UTC ISO instant into the calendar date + wall-clock time it falls on
 * in `timeZone` — the inverse of `zonedWallTimeToUtcISO`, for pre-filling a
 * scheduler. `date` is a Date at local midnight of that day (so date-fns
 * `format(date, 'yyyy-MM-dd')` yields the zoned day); `time` is 'HH:mm'.
 */
export function utcToZonedParts(iso: string, timeZone: string): { date: Date; time: string } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(new Date(iso));
  const get = (type: string) => parts.find(p => p.type === type)?.value ?? '';
  // Intl can render midnight as hour "24"; normalise it back to "00".
  const hour = get('hour') === '24' ? '00' : get('hour');
  const date = new Date(`${get('year')}-${get('month')}-${get('day')}T00:00:00`);
  return { date, time: `${hour}:${get('minute')}` };
}

/** Formats a UTC ISO instant for display in `timeZone`, e.g. "Jul 20, 2026, 9:00 AM PDT". */
export function formatInTimezone(iso: string, timeZone: string): string {
  return new Intl.DateTimeFormat('en-US', {
    timeZone,
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZoneName: 'short',
  }).format(new Date(iso));
}

const DEFAULT_TIMEZONE: SupportedTimezone = 'America/Los_Angeles';

/**
 * Detects the user's browser timezone and returns it if supported,
 * otherwise returns the default timezone.
 */
export function detectTimezone(): string {
  try {
    const browserTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;

    // Check if the browser timezone is directly supported
    if (SUPPORTED_TIMEZONES.includes(browserTimezone as SupportedTimezone)) {
      return browserTimezone as SupportedTimezone;
    }

    // Map common timezone aliases to supported timezones
    const timezoneMapping: Record<string, SupportedTimezone> = {
      // US timezones
      'America/Detroit': 'America/New_York',
      'America/Indiana/Indianapolis': 'America/New_York',
      'America/Kentucky/Louisville': 'America/New_York',
      'America/Toronto': 'America/New_York',
      'America/Montreal': 'America/New_York',
      'America/Winnipeg': 'America/Chicago',
      'America/Edmonton': 'America/Denver',
      'America/Phoenix': 'America/Denver',
      'America/Vancouver': 'America/Los_Angeles',
      'America/Tijuana': 'America/Los_Angeles',
      // Europe
      'Europe/Berlin': 'Europe/Paris',
      'Europe/Amsterdam': 'Europe/Paris',
      'Europe/Brussels': 'Europe/Paris',
      'Europe/Madrid': 'Europe/Paris',
      'Europe/Rome': 'Europe/Paris',
      'Europe/Vienna': 'Europe/Paris',
      'Europe/Warsaw': 'Europe/Paris',
      'Europe/Zurich': 'Europe/Paris',
      'Europe/Dublin': 'Europe/London',
      'Europe/Lisbon': 'Europe/London',
      // Asia
      'Asia/Seoul': 'Asia/Tokyo',
      'Asia/Hong_Kong': 'Asia/Shanghai',
      'Asia/Taipei': 'Asia/Shanghai',
      'Asia/Singapore': 'Asia/Shanghai',
      // Australia
      'Australia/Melbourne': 'Australia/Sydney',
      'Australia/Brisbane': 'Australia/Sydney',
    };

    if (timezoneMapping[browserTimezone]) {
      return timezoneMapping[browserTimezone];
    }

    return DEFAULT_TIMEZONE;
  } catch {
    return DEFAULT_TIMEZONE;
  }
}
