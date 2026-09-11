class AddDisabledAtToPromoCodes < ActiveRecord::Migration[8.1]
  # The one lifecycle column promo codes were missing (issue #180).
  #
  # A code could be created and could expire on its own once `expires_at` passed,
  # but a support agent had no way to pull a live code out of circulation early —
  # a leaked general code, say. `disabled_at` is that switch, with the same
  # nullable-and-nil-is-normal shape as `cards.flagged_at`; redemption checks it
  # the way it already checks `expires_at`.
  def change
    add_column :promo_codes, :disabled_at, :datetime
  end
end
