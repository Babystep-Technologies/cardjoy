# typed: true
# frozen_string_literal: true

# Picks a "curated design" for an occasion reminder.
#
# Design decision (issue #28): CardJoy's Style/Tag data models a card's colours
# and effects, not occasion-specific artwork — there are no seeded "cover"
# styles and the `style_tags` join is empty in every environment, so mapping
# `Occasion#kind` onto style tags would resolve to nothing. Instead this is a
# small hand-curated lookup from occasion kind to a human-readable design idea
# (a headline + blurb the reminder email shows, and an `effect` slug that lines
# up with the seeded effect styles the create flow offers). It needs no data,
# is deterministic, and is trivial to test. Swap it for a tag- or
# popularity-driven mapping once occasion-specific artwork exists.
module OccasionDesignSuggestion
  extend T::Sig

  Suggestion = Struct.new(:headline, :blurb, :effect, keyword_init: true)

  # Keyed by the occasion kinds in `Card::OCCASIONS`. `effect` matches a seeded
  # effect style value (e.g. "confetti") so the suggestion is consistent with
  # what the create flow can render.
  SUGGESTIONS = T.let(
    {
      "Birthday" => Suggestion.new(headline: "Confetti Celebration", blurb: "A bright, playful design with a confetti burst to make their day feel special.", effect: "confetti"),
      "Wedding" => Suggestion.new(headline: "Elegant Blooms", blurb: "A soft, romantic design with gentle falling petals to mark the occasion.", effect: "hearts"),
      "Baby Shower" => Suggestion.new(headline: "Sweet Arrival", blurb: "A tender pastel design to welcome the little one on the way.", effect: "confetti"),
      "Retirement" => Suggestion.new(headline: "Cheers to What's Next", blurb: "A warm, celebratory design honouring a well-earned new chapter.", effect: "confetti"),
      "Graduation" => Suggestion.new(headline: "Cap & Confetti", blurb: "A proud, festive design to celebrate the big achievement.", effect: "confetti"),
      "Anniversary" => Suggestion.new(headline: "Years of Love", blurb: "A heartfelt design with drifting hearts to celebrate the milestone.", effect: "hearts"),
      "New Baby" => Suggestion.new(headline: "Sweet Arrival", blurb: "A tender pastel design to welcome the little one.", effect: "confetti"),
      "Engagement" => Suggestion.new(headline: "She Said Yes", blurb: "A joyful, romantic design to celebrate the happy news.", effect: "hearts"),
      "Congratulations" => Suggestion.new(headline: "Way to Go", blurb: "A bright, upbeat design with a confetti burst for the big win.", effect: "confetti"),
      "Thank You" => Suggestion.new(headline: "Heartfelt Thanks", blurb: "A warm, understated design to say a genuine thank you.", effect: nil),
      "Sympathy" => Suggestion.new(headline: "With Sympathy", blurb: "A calm, gentle design offering comfort and care.", effect: nil),
      "Get Well Soon" => Suggestion.new(headline: "Feel Better Soon", blurb: "A cheerful, hopeful design to brighten their recovery.", effect: nil),
      "New Job" => Suggestion.new(headline: "New Beginnings", blurb: "A confident, celebratory design for an exciting new role.", effect: "confetti"),
      "Farewell" => Suggestion.new(headline: "Until We Meet Again", blurb: "A warm, sincere design to wish them well on their way.", effect: nil),
      "Holiday" => Suggestion.new(headline: "Season's Greetings", blurb: "A festive, cosy design to share the holiday spirit.", effect: "sparkles"),
      "Mother's Day" => Suggestion.new(headline: "For Mom", blurb: "A loving, floral design to celebrate her.", effect: "hearts"),
      "Father's Day" => Suggestion.new(headline: "For Dad", blurb: "A warm, classic design to celebrate him.", effect: nil),
      "Valentine's Day" => Suggestion.new(headline: "Be Mine", blurb: "A romantic design with drifting hearts.", effect: "hearts"),
      "Friendship" => Suggestion.new(headline: "Just for You", blurb: "A cheerful, colourful design to celebrate your friendship.", effect: "confetti"),
      "Just Because" => Suggestion.new(headline: "Thinking of You", blurb: "A simple, warm design to brighten their day for no reason at all.", effect: nil),
      "First day at work" => Suggestion.new(headline: "New Beginnings", blurb: "An encouraging, upbeat design for a great first day.", effect: "confetti"),
      "Last day at work" => Suggestion.new(headline: "Until We Meet Again", blurb: "A warm send-off design for a fond farewell.", effect: nil),
      "Promotion at work" => Suggestion.new(headline: "Well Deserved", blurb: "A celebratory design with a confetti burst for the big step up.", effect: "confetti"),
      "Work anniversary" => Suggestion.new(headline: "Another Great Year", blurb: "A bright, appreciative design to mark the milestone.", effect: "confetti")
    }.freeze,
    T::Hash[String, Suggestion]
  )

  # A safe generic suggestion for any kind not in the lookup.
  DEFAULT = T.let(
    Suggestion.new(headline: "A Card for the Occasion", blurb: "A thoughtful design to help you mark the moment.", effect: "confetti"),
    Suggestion
  )

  sig { params(kind: T.nilable(String)).returns(Suggestion) }
  def self.for(kind)
    return DEFAULT if kind.nil?
    SUGGESTIONS.fetch(kind, DEFAULT)
  end
end
