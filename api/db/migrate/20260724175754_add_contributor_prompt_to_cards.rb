# typed: false
# frozen_string_literal: true

class AddContributorPromptToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :contributor_prompt, :text
  end
end
