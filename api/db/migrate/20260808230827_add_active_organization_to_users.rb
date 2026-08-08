class AddActiveOrganizationToUsers < ActiveRecord::Migration[8.1]
  def change
    # The organization the user is currently acting in. NULL means Personal,
    # which is a valid context rather than a missing value — every user starts
    # there and can switch back at any time.
    #
    # This lives on the row rather than in the JWT: tokens are minted with a
    # six-month expiry (Mutations::SignIn), so a switch would need a re-mint and
    # losing a membership would not take effect until the token expired.
    #
    # on_delete: :nullify because a hard-deleted organization must not leave the
    # user unsavable. Organizations are normally soft-deleted (#archive!), which
    # this FK never sees.
    add_reference :users, :active_organization,
                  null: true,
                  index: true,
                  foreign_key: { to_table: :organizations, on_delete: :nullify }
  end
end
