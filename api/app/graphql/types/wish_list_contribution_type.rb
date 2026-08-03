# typed: true
# frozen_string_literal: true

module Types
  class WishListContributionType < Types::BaseObject
    field :id, ID, null: false
    field :kind, String, null: false
    field :handle, String, null: false
    field :label, String, null: true
    field :suggested_amount, String, null: true
    field :note, String, null: true
    field :position, Integer, null: false

    # Null for kinds with no deep link (Zelle, Trump Account) — the guest sends manually.
    field :action_url, String, null: true
  end
end
