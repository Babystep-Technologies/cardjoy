# typed: false
# frozen_string_literal: true

class AddDeliverToEmailToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :deliver_to_email, :string
  end
end
