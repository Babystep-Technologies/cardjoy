/**
 * Effect slugs mirror the `source` column of `kind: "effect"` styles seeded in
 * api/db/seeds.rb, which the GraphQL API exposes as `Style.value`.
 */
export const EFFECT_SLUGS = ['confetti', 'sparkles', 'hearts'] as const;

export type EffectSlug = (typeof EFFECT_SLUGS)[number];

export function isEffectSlug(value: string | null | undefined): value is EffectSlug {
  return !!value && (EFFECT_SLUGS as readonly string[]).includes(value);
}
