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
