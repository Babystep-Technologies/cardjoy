import posthog from 'posthog-js';

const ENV = import.meta.env.VITE_ENV || 'development';
const ENABLED_ENVS = ['production', 'staging']; // Only send events in these envs

function shouldCapture() {
  return ENABLED_ENVS.includes(ENV);
}

export function captureError(event: string, properties: Record<string, string> = {}) {
  if (shouldCapture()) {
    posthog.capture(event, { ...properties, level: 'error', source: 'web' });
  } else {
    console.error(`[PostHog][${event}]`, properties);
  }
}

export function captureInfo(event: string, properties: Record<string, string> = {}) {
  if (shouldCapture()) {
    posthog.capture(event, { ...properties, level: 'info', source: 'web' });
  } else {
    console.info(`[PostHog][${event}]`, properties);
  }
}
