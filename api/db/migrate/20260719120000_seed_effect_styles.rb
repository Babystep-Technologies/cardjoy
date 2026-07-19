# typed: false

# Seed the `kind: "effect"` styles in every environment. These were added to
# db/seeds.rb after production had already been seeded with the color styles, so
# production has background/text colors but no effects — the 1-on-1 creation
# form renders the "Effect" section with no chips to pick. Seeds only run on a
# fresh setup, so a migration is how the existing production database gets them.
#
# Idempotent and self-healing: matches on name + kind and rewrites `source` (the
# slug the web app switches on), so re-runs are safe and any stale slug is fixed.
class SeedEffectStyles < ActiveRecord::Migration[8.1]
  EFFECTS = [
    { name: "Confetti", source: "confetti" },
    { name: "Sparkles", source: "sparkles" },
    { name: "Floating Hearts", source: "hearts" }
  ].freeze

  def up
    EFFECTS.each do |effect|
      style = Style.find_or_initialize_by(name: effect[:name], kind: "effect")
      style.update!(source: effect[:source])
    end
  end

  def down
    Style.where(kind: "effect", name: EFFECTS.map { |e| e[:name] }).delete_all
  end
end
