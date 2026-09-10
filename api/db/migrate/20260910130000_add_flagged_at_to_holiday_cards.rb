class AddFlaggedAtToHolidayCards < ActiveRecord::Migration[8.1]
  # The one moderation column holiday cards were missing (issue #178).
  #
  # `deleted_at` already exists, so archive worked the moment an admin mutation
  # could call it; flag had nowhere to write. Same meaning as `cards.flagged_at`,
  # so Mutations::UpdateHolidayCardByAdmin can mirror UpdateCardByAdmin exactly.
  #
  # Nullable, and nil is the normal state — which is what every existing row is.
  def change
    add_column :holiday_cards, :flagged_at, :datetime
  end
end
