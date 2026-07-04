# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :name,               null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Email verification (custom confirmation)
      t.boolean  :email_confirmed,       default: false
      t.string   :confirmation_code
      t.datetime :confirmation_sent_at

      ## OmniAuth (Google, etc.)
      t.string :provider
      t.string :uid

      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, [ :provider, :uid ], unique: true
  end
end
