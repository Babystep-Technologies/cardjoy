# typed: false
# frozen_string_literal: true

class AddDeliverAtToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :deliver_at, :datetime
  end
end
