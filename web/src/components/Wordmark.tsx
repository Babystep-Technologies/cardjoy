import type { SVGProps } from 'react';

/**
 * The Felicito wordmark as an inline SVG so its colors can be driven from CSS.
 *
 * The sparkle (the "o") behaves exactly like the old header logo: it cycles through
 * the brand colors via `animate-brand-cycle` (green → pink → blue → yellow), because it
 * paints with `currentColor`. Pass `animateSparkle={false}` to make it static, or pin a
 * color with the `--wordmark-sparkle` CSS variable, e.g.
 * `className="[--wordmark-sparkle:var(--color-brand-pink)]"`. Letters default to black and
 * can be overridden with `--wordmark-letters`.
 *
 * Keep the paths in sync with `public/font-logo.svg` (still used where an <img> is
 * required, e.g. emails and the brand preview, where the sparkle stays black).
 */
interface WordmarkProps extends SVGProps<SVGSVGElement> {
  animateSparkle?: boolean;
}

const Wordmark: React.FC<WordmarkProps> = ({ animateSparkle = true, ...props }) => (
  <svg
    viewBox="0 0 556.711 137"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-label="Felicito"
    {...props}
  >
    <g>
      <path
        d="M21 45.976C21 20.9 28.857 6.356 60.954 5.687L63.295 28.255C51.424 29.426 48.248 32.937 48.248 42.298L48.248 124.378L21 124.378L21 45.976Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        d="M0 43.298L69.248 43.298L69.248 59.298L0 59.298Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        d="M159.3 100C153.925 116.019 138.615 126.552 119.55 126.552C94.14 126.552 75.248 108.497 75.248 83.757C75.248 59.181 94.14 41.128 119.55 41.128C141.951 41.128 159.17 55.671 161.175 76.568L161.175 89.5L101.823 89.5C103.803 97.71 110.135 103.649 119.717 103.649C123.897 103.649 127.598 102.299 130.399 100ZM135.598 76.568C134.261 69.212 127.907 64.029 119.717 64.029C110.716 64.029 104.582 69.173 102.23 76.568Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        d="M170.175 5.687L197.257 5.687L197.257 124.378L170.175 124.378Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        d="M208.957 15.38C208.957 6.519 216.145 0 224.838 0C233.698 0 240.719 6.519 240.719 15.38C240.719 24.073 233.698 30.593 224.838 30.593C216.145 30.593 208.957 24.073 208.957 15.38Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        d="M211.298 43.298L238.546 43.298L238.546 124.378L211.298 124.378Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        transform="translate(249.719 0)"
        d="M60.35 91.1119H85.9274C83.9219 112.009 66.7033 126.552 44.3019 126.552C18.8915 126.552 0 108.497 0 83.7566C0 59.1813 18.8915 41.1278 44.3019 41.1278C66.7033 41.1278 83.9219 55.6714 85.9274 76.5683H60.35C59.0125 69.2116 52.6592 64.0287 44.4689 64.0287C32.7671 64.0287 25.9114 72.7229 25.9114 83.7566C25.9114 94.7903 32.7671 103.649 44.4689 103.649C52.6592 103.649 59.0125 98.4673 60.35 91.1119Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        d="M344.646 15.38C344.646 6.519 351.834 0 360.527 0C369.387 0 376.408 6.519 376.408 15.38C376.408 24.073 369.387 30.593 360.527 30.593C351.834 30.593 344.646 24.073 344.646 15.38Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        d="M346.987 43.298L374.235 43.298L374.235 124.378L346.987 124.378Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        d="M409.108 86.263C409.108 111.339 416.965 125.883 449.062 126.552L451.403 103.984C439.532 102.813 436.356 99.302 436.356 89.941L436.356 22L409.108 22L409.108 86.263Z"
        fill="var(--wordmark-letters, #000)"
      />
      <path
        d="M388.108 43.298L457.356 43.298L457.356 59.298L388.108 59.298Z"
        fill="var(--wordmark-letters, #000)"
      />
    </g>
    <g
      className={animateSparkle ? 'animate-brand-cycle' : undefined}
      data-wordmark="sparkle"
      stroke="var(--wordmark-sparkle, currentColor)"
      strokeWidth={1.41}
    >
      <path
        transform="translate(78.522 0)"
        d="M410.858 81.791L387.788 62.8146L399.323 50.9077L420.903 66.35V36.0258H438.02V66.1632L455.508 44.5926L464.809 51.2799L448.81 74.3493L473.74 71.3729V81.791L454.019 87.0007L473.74 101.512L465.926 114.534L447.321 101.883L450.298 126.069L435.787 129.045L430.764 103.744L413.834 131.649L401.556 126.813L414.578 99.1864L391.509 109.696L387.788 90.7215L410.858 81.791Z"
        fill="var(--wordmark-sparkle, currentColor)"
      />
      <path
        transform="translate(78.522 0)"
        d="M406.12 125.003L412.425 127.488L432.371 94.6092L438.42 125.076L446.578 123.402L443.076 94.9376L464.869 109.757L469.278 102.408L446.366 85.5471L470.373 79.2065V75.1602L441.787 78.5739L460.161 52.0837L456.116 49.1753L434.654 75.6471V39.3871H424.259V72.8886L399.717 55.329L392.733 62.5371L417.428 82.8509L391.623 92.8401L393.984 104.876L421.521 92.3306L406.12 125.003ZM415.232 135.817L396.981 128.627L407.624 106.046L389.026 114.521L383.944 88.6055L404.277 80.7365L382.834 63.0962L398.919 46.4933L417.537 59.8155V32.6672H441.375V56.6849L454.889 40.014L469.448 50.483L455.823 70.1302L477.095 67.5897V84.3809L461.662 88.4584L478.189 100.619L466.972 119.315L451.557 108.833L454.007 128.741L433.144 133.018L429.147 112.882L415.232 135.817Z"
        fill="var(--wordmark-sparkle, currentColor)"
      />
    </g>
  </svg>
);

export default Wordmark;
