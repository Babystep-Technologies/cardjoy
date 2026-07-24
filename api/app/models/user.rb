# typed: true

class User < ApplicationRecord
  extend T::Sig

  # Free credits every new user receives on creation so they can try the
  # product before buying. See #grant_signup_credits.
  SIGNUP_CREDIT_GRANT = 5

  # Cost, in credits, of creating a card or invitation. See #spend_credit!.
  CREATION_CREDIT_COST = 1

  # Raised by #spend_credit! when the user cannot afford a creation.
  class InsufficientCreditsError < StandardError; end

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
  has_many :contacts, dependent: :destroy
  has_many :occasions, through: :contacts

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  after_create :grant_signup_credits

  # Signed sum of the credit ledger. Positive rows are grants/purchases,
  # negative rows are spends.
  sig { returns(Integer) }
  def credit_balance
    credits.sum(:amount).to_i
  end

  # Debit a single credit for a card/invitation creation. Must run inside a
  # transaction: it locks the user row for the duration of that transaction so
  # concurrent creations can't drive the balance below zero, checks the
  # balance, then writes a negative ledger row. Raises InsufficientCreditsError
  # (rolling back the surrounding transaction) when the user can't afford it.
  sig { params(reason: String, event_kind: String, event_data: T::Hash[T.untyped, T.untyped]).returns(Credit) }
  def spend_credit!(reason:, event_kind:, event_data: {})
    lock!
    raise InsufficientCreditsError, "Not enough credits" if credit_balance < CREATION_CREDIT_COST

    credits.create!(
      amount: -CREATION_CREDIT_COST,
      reason: reason,
      events: [
        {
          event_kind: event_kind,
          event_happened_at: Time.now.utc.iso8601(3),
          event_data: event_data
        }
      ]
    )
  end

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
    # No email means we can't create a real, reachable, billable account
    # (mainly Slack Connect / external guests). Don't synthesize a shadow
    # account — return nil so the caller routes the user through the connect
    # flow instead. See issue #81.
    return nil if email.blank?

    effective_email = email.downcase
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

  private

  # Grant the one-time signup bonus. Guarded on the presence of an existing
  # signup_bonus row so re-running the callback (or a backfill) can't
  # double-grant. Runs as an after_create callback so every creation path
  # (email signup, Google/Slack OAuth, seeds, admin) is covered.
  sig { void }
  def grant_signup_credits
    return if credits.where(reason: "signup_bonus").exists?

    credits.create!(
      amount: SIGNUP_CREDIT_GRANT,
      reason: "signup_bonus",
      events: [
        {
          event_kind: "signup_bonus",
          event_happened_at: Time.now.utc.iso8601(3),
          event_data: {}
        }
      ]
    )
  end
end
