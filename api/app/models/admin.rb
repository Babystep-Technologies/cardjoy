# typed: true

class Admin < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :google_uid, presence: true

  def self.from_google(uid:, email:, name:)
    normalized_email = email.downcase

    unless Rails.application.credentials.admin_emails.include?(normalized_email)
      raise StandardError, "This email is not authorized for admin access"
    end

    find_or_create_by!(google_uid: uid) do |admin|
      admin.email = normalized_email
      admin.name = name
    end
  end
end
