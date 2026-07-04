class MakeRsvpUserOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :rsvps, :user_id, true
  end
end
