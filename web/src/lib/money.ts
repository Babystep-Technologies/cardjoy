/**
 * Formatting money that arrived as integer US cents.
 *
 * Every amount the API returns for postage — `totalCents`, `chargedCents`,
 * `postageBalanceCents` — is an integer number of cents, on purpose: cents
 * survive JSON exactly, dollars do not. `4.10` is not representable in a float,
 * so `total / 100` and a `toFixed(2)` is a rounding bug waiting for a large
 * enough send, and summing dollars is worse.
 *
 * So nothing here divides. The split into dollars and cents is integer
 * arithmetic (`trunc` and `%`), and the only string work happens after the two
 * halves are already exact. Anything that adds money adds cents and formats at
 * the very end.
 */

/** "$0.42", "$1,240.00", "-$3.20". Input must be an integer number of cents. */
export function formatCents(cents: number): string {
  const rounded = Math.round(cents);
  const negative = rounded < 0;
  const absolute = Math.abs(rounded);

  // Integer halves, never a division that produces a fraction.
  const dollars = Math.trunc(absolute / 100);
  const remainder = absolute % 100;

  const grouped = dollars.toLocaleString('en-US');
  return `${negative ? '-' : ''}$${grouped}.${String(remainder).padStart(2, '0')}`;
}

/** "1 card" / "38 cards" — pluralising a count without a template at each call site. */
export function pluralize(count: number, singular: string, plural = `${singular}s`): string {
  return `${count} ${count === 1 ? singular : plural}`;
}
