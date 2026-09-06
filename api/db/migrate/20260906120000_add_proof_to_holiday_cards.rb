class AddProofToHolidayCards < ActiveRecord::Migration[8.1]
  # The PostGrid-rendered proof a user approves before we print (issue #144).
  #
  # Every column is nullable: nil across all four is the normal state of a card
  # being designed, and is what "no proof yet" means.
  #
  # `proof_design_digest` is the load-bearing one. It is a hash of the exact
  # design the proof was rendered from, so comparing it against the card's
  # current digest answers "is this PDF still a picture of this card?" — the one
  # question the send flow (#148) has to get right, because there is no undo
  # once an order is printing.
  def change
    add_column :holiday_cards, :proof_url, :string
    add_column :holiday_cards, :proof_generated_at, :datetime
    add_column :holiday_cards, :proof_design_digest, :string
    add_column :holiday_cards, :proof_approved_at, :datetime
  end
end
