# frozen_string_literal: true

# A card can point guests at one of its owner's registries (#250). Nullable and nullified when the
# registry is deleted, so removing a registry never breaks a card.
class AddWishListToCards < ActiveRecord::Migration[8.1]
  def change
    add_reference :cards, :wish_list, foreign_key: { on_delete: :nullify }, index: true
  end
end
