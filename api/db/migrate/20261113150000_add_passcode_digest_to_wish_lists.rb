# An optional passcode a guest must enter to open a registry (#247). Only a salted digest is kept.
class AddPasscodeDigestToWishLists < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_lists, :passcode_digest, :string
  end
end
