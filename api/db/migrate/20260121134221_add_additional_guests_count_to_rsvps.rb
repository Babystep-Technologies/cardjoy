class AddAdditionalGuestsCountToRsvps < ActiveRecord::Migration[8.0]
  def change
    add_column :rsvps, :additional_guests_count, :integer, default: 0

    # Migrate existing data: convert plus_one boolean to count
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE rsvps SET additional_guests_count = 1 WHERE plus_one = true
        SQL
      end
    end
  end
end
