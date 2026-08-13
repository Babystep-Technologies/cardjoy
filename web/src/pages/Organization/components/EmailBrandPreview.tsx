import React from 'react';

/**
 * What an outgoing email looks like with the organization's branding applied.
 *
 * This mirrors `api/app/views/layouts/mailer.html.erb` and the fallbacks in
 * `api/app/mailers/mailer_brand.rb` — the layout is the one thing an admin can't otherwise inspect,
 * and getting a branded email wrong means getting it wrong for their whole team. Keep the constants
 * below in step with `MailerBrand`; a drift here shows admins a preview their recipients never see.
 */

/** MailerBrand::ACCENT_COLOR, BODY_BACKGROUND, and TEXT_COLOR. */
const CARDJOY_ACCENT_COLOR = '#433c69';
const CARDJOY_BODY_BACKGROUND = '#fefaf9';
const CARDJOY_TEXT_COLOR = '#573b6f';

/**
 * The real emails use the hosted logo in `Rails.configuration.x.app_logo_for_email`; this is the
 * same wordmark served from the web app, so the preview stays accurate without a network round trip.
 */
const CARDJOY_LOGO_URL = '/font-logo.svg';

const cardjoyFooterText = () =>
  `© ${new Date().getFullYear()} BabyStep Technologies, Inc. All rights reserved.`;

export interface EmailBrandPreviewProps {
  /** The organization's name, used as the alt text for its own logo. */
  organizationName: string;
  /** A saved logo URL, or an object URL for a logo the admin has picked but not saved yet. */
  logoUrl: string | null;
  accentColor: string;
  footerText: string;
  replyTo: string;
}

const EmailBrandPreview: React.FC<EmailBrandPreviewProps> = ({
  organizationName,
  logoUrl,
  accentColor,
  footerText,
  replyTo,
}) => {
  // Each value falls back the way MailerBrand does, so a blank field previews the CardJoy default
  // rather than an empty space. An invalid accent color is left to the server to reject; previewing
  // it as typed is what tells the admin the value isn't a color.
  const brandedLogo = logoUrl?.trim() ? logoUrl.trim() : null;
  const resolvedLogo = brandedLogo ?? CARDJOY_LOGO_URL;
  const resolvedLogoAlt = brandedLogo ? organizationName : 'CardJoy Logo';
  const resolvedAccent = accentColor.trim() || CARDJOY_ACCENT_COLOR;
  const resolvedFooter = footerText.trim() || cardjoyFooterText();
  const resolvedReplyTo = replyTo.trim();

  return (
    <div className="space-y-3">
      <div
        className="overflow-hidden rounded-lg border border-gray-200"
        style={{ backgroundColor: CARDJOY_BODY_BACKGROUND, color: CARDJOY_TEXT_COLOR }}
        aria-label="Email preview"
      >
        <div className="px-6 pt-6 pb-3 text-center">
          <img
            src={resolvedLogo}
            alt={resolvedLogoAlt}
            className="mx-auto h-auto max-h-16 w-40 object-contain"
          />
        </div>

        <div className="mx-4 mb-6 rounded-xl bg-white p-6 text-[#2b2c4b] shadow-[0_4px_16px_rgba(0,0,0,0.06)]">
          {/* `h3` picks up Source Serif 4 from index.css, the same face the mailer layout uses. */}
          <h3 className="text-xl font-bold">You've been invited to sign a card</h3>
          <p className="mt-2 text-sm">
            {organizationName || 'Your organization'} is putting together a card for Jordan. Add
            your message before it's sent.
          </p>
          <p className="mt-4">
            <span
              className="inline-block rounded-md border-2 px-5 py-2.5 text-sm font-semibold"
              style={{ borderColor: resolvedAccent, color: resolvedAccent }}
            >
              Sign the card
            </span>
          </p>
        </div>

        <p className="px-6 pb-6 text-center text-xs break-words text-[#999]">{resolvedFooter}</p>
      </div>

      <p className="text-xs text-gray-500">
        {resolvedReplyTo ? (
          <>
            Replies go to <span className="font-medium text-gray-700">{resolvedReplyTo}</span>.
          </>
        ) : (
          <>Replies go to CardJoy. Set a reply-to address to route them to your team instead.</>
        )}{' '}
        Email is always sent from CardJoy's own address, so your domain's deliverability is
        untouched.
      </p>
    </div>
  );
};

export default EmailBrandPreview;
