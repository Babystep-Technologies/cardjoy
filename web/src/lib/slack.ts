/**
 * Slack OAuth install helpers.
 *
 * Bot scopes are kept to the minimum the CardJoy flow actually uses:
 *   - `commands`         — register and receive the `/cardjoy` slash command, open
 *                          modals (`views.open`), and post the follow-up message via
 *                          `response_url`.
 *   - `users:read`       — resolve the recipient's display name via `users.info`.
 *   - `users:read.email` — read the member's profile email via `users.info`, so
 *                          `/cardjoy` users resolve to a real, billable account
 *                          instead of a synthetic `slack+…@cardjoy.app` address.
 *
 * Keep this list in sync with the scopes configured on the Slack app manifest.
 * It is the single source of truth for the "Add to Slack" button across the app,
 * so a scope missing here is a scope new installs never consent to.
 */
export const SLACK_BOT_SCOPES = ['commands', 'users:read', 'users:read.email'] as const;

/**
 * Embed URL for the Slack demo video shown on the `/slack` landing page (`#demo`).
 *
 * Leave as `null` until the video exists — the section renders a placeholder poster.
 * When ready, set this to the embed URL (YouTube/Vimeo/Loom `<iframe>` src). If the
 * video is a self-hosted MP4 instead, swap the embed markup in `Slack.tsx` for a
 * `<video>` tag; this constant is the only wiring the placeholder path depends on.
 */
export const DEMO_VIDEO_URL: string | null = null;

/** Builds the Slack OAuth v2 authorize URL that the "Add to Slack" button links to. */
export function slackInstallUrl(): string {
  const clientId = import.meta.env.VITE_SLACK_CLIENT_ID;
  const redirectUri = `${import.meta.env.VITE_API_URL}/oauth/slack/callback`;
  const params = new URLSearchParams({
    client_id: clientId,
    scope: SLACK_BOT_SCOPES.join(','),
    redirect_uri: redirectUri,
  });
  return `https://slack.com/oauth/v2/authorize?${params.toString()}`;
}
