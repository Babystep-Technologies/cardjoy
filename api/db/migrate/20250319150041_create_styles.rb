class CreateStyles < ActiveRecord::Migration[8.0]
  def change
    create_table :styles do |t|
      t.string :name
      t.string :kind
      t.string :source
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
