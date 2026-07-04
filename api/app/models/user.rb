# typed: true

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, :omniauthable,
         jwt_revocation_strategy: Devise::JWT::RevocationStrategies::Null,
         omniauth_providers: [ :google_oauth2 ]

  has_many :cards, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :credits, dependent: :destroy
  has_many :promo_codes, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :rsvps, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  # ---------------------
  # OAuth: Google
  # ---------------------
  def self.from_google(uid:, email:, full_name:)
    user = find_or_initialize_by(provider: "google_oauth2", uid: uid)
    user.assign_attributes(
      email: email,
      name: full_name,
      password: Devise.friendly_token[0, 20],
      email_confirmed: true
    )
    user.save! if user.changed?
    user
  end

  # ---------------------
  # OAuth: Slack (auto-provision)
  # ---------------------
  def self.from_slack(slack_user_id:, slack_team_id:, email: nil, name: nil)
    effective_email = (email.presence || "slack+#{slack_user_id}+#{slack_team_id}@cardjoy.app").downcase
    effective_name = name.presence || "Slack User"
    uid = "#{slack_team_id}:#{slack_user_id}"

    # Prefer linking to an existing user with the same email
    user = find_by(email: effective_email)
    return user if user

    # Fall back to provider/uid lookup (prevents duplicates)
    user = find_by(provider: "slack", uid: uid)
    return user if user

    create!(
      provider: "slack",
      uid: uid,
      email: effective_email,
      name: effective_name,
      password: Devise.friendly_token[0, 20],
      email_confirmed: true
    )
  end

  # ---------------------
  # Confirmation Code Logic (for email/password signups)
  # ---------------------

  def generate_confirmation_code!
    update!(
      confirmation_code: rand(100000..999999).to_s,
      confirmation_sent_at: Time.current
    )
    UserMailer.confirmation_code(user: self).deliver_later
  end

  def confirmation_code_expired?
    confirmation_sent_at.nil? || T.must(confirmation_sent_at) < 15.minutes.ago
  end

  def confirm_email!(code)
    return false if confirmation_code_expired?
    return false unless confirmation_code == code

    update!(
      email_confirmed: true,
      confirmation_code: nil,
      confirmation_sent_at: nil
    )
  end
end
