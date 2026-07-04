class RenameMetadataToEvents < ActiveRecord::Migration[7.0]
  def change
    rename_column :credits, :metadata, :events
  end
end
