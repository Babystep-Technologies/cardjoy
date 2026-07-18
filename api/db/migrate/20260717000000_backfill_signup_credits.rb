# typed: false

# One-time retroactive signup grant for users who predate the credits economy.
# Only users with zero lifetime credit rows are granted, so anyone who already
# purchased, redeemed, or was granted credits is left untouched and no one is
# double-granted. New users get the grant via User#grant_signup_credits.
class BackfillSignupCredits < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    User.where.missing(:credits).find_each do |user|
      user.credits.create!(
        amount: User::SIGNUP_CREDIT_GRANT,
        reason: "signup_bonus",
        events: [
          {
            event_kind: "signup_bonus",
            event_happened_at: Time.now.utc.iso8601(3),
            event_data: { backfill: true }
          }
        ]
      )
    end
  end

  def down
    # Irreversible: once granted, a signup bonus is indistinguishable from one
    # granted at signup, and users may have already spent it.
    raise ActiveRecord::IrreversibleMigration
  end
end
