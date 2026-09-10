class AddModerationToInvitations < ActiveRecord::Migration[8.1]
  # The moderation columns invitations have never had (issue #177).
  #
  # Cards carry `flagged_at`, `locked_at`, and `deleted_at` and the admin
  # dashboard acts on all three; invitations carry none, so an abuse report
  # about an invitation has had no answer at all. These are the same three
  # columns with the same meanings, so one admin mutation can serve both
  # products — see Mutations::UpdateInvitationByAdmin.
  #
  # Every column is nullable and nil is the normal state: nil across all three
  # is an ordinary live invitation, which is what every existing row is.
  #
  # `deleted_at` is the load-bearing one. Adding it also adds Invitation's
  # `default_scope`, so archiving finally hides an invitation from guests
  # instead of only labelling it in admin. There is no user-facing invitation
  # delete today, so nothing else writes this column.
  def change
    add_column :invitations, :flagged_at, :datetime
    add_column :invitations, :locked_at, :datetime
    add_column :invitations, :deleted_at, :datetime

    add_index :invitations, :deleted_at
  end
end
