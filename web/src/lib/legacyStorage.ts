import { APP_TOKEN_KEY, LEGACY_APP_TOKEN_KEY } from '@/lib/constants';

const LEGACY_RSVP_PREFIX = 'cardjoy_rsvp_';
const RSVP_PREFIX = 'felicito_rsvp_';

/**
 * One-time move of localStorage keys from the CardJoy-era names to the Felicito names, so a
 * rename never logs anyone out or forgets an RSVP. Copies the old value only when the new key is
 * empty, then deletes the old key. Safe to call on every boot; storage can throw (private mode),
 * so everything is guarded and failures are silent.
 */
export function migrateLegacyStorageKeys(storage: Storage = localStorage): void {
  try {
    const legacyToken = storage.getItem(LEGACY_APP_TOKEN_KEY);
    if (legacyToken !== null) {
      if (storage.getItem(APP_TOKEN_KEY) === null) storage.setItem(APP_TOKEN_KEY, legacyToken);
      storage.removeItem(LEGACY_APP_TOKEN_KEY);
    }

    const legacyRsvpKeys: string[] = [];
    for (let i = 0; i < storage.length; i += 1) {
      const key = storage.key(i);
      if (key?.startsWith(LEGACY_RSVP_PREFIX)) legacyRsvpKeys.push(key);
    }
    legacyRsvpKeys.forEach(key => {
      const newKey = RSVP_PREFIX + key.slice(LEGACY_RSVP_PREFIX.length);
      const value = storage.getItem(key);
      if (value !== null && storage.getItem(newKey) === null) storage.setItem(newKey, value);
      storage.removeItem(key);
    });
  } catch {
    // Storage unavailable: nothing to migrate.
  }
}
