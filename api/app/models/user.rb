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

  # Raised by #spend_postage! when the postage wallet can't cover a piece of
  # mail. Separate from InsufficientCreditsError: the two wallets are separate
  # products, and a caller topping up postage should not be told to buy credits.
  class InsufficientPostageError < StandardError; end

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, :omniauthable,
         jwt_revocation_strategy: Devise::JWT::RevocationStrategies::Null,
         omniauth_providers: [ :google_oauth2 ]

  has_many :cards, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :credits, dependent: :destroy
  has_many :postage_credits, dependent: :destroy
  has_many :promo_codes, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :holiday_cards, dependent: :destroy
  # Declared after :holiday_cards so a user destroy takes the cards (and their
  # orders) first and finds nothing left to do here.
  has_many :holiday_card_mail_orders, dependent: :destroy
  has_many :rsvps, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :contact_lists, dependent: :destroy
  has_many :occasions, through: :contacts
  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships

  # Invitations this user sent, not ones addressed to them: an invitation is
  # addressed to an email, which may not belong to any user yet.
  has_many :sent_organization_invitations,
           class_name: "OrganizationInvitation",
           foreign_key: :invited_by_id,
           inverse_of: :invited_by,
           dependent: :destroy

  # The organization the user is currently acting in; nil means Personal. See
  # Mutations::SwitchOrganization. Reads nil for an archived organization too,
  # because Organization is default-scoped to `deleted_at: nil` — an archived
  # context degrades to Personal rather than to a dangling reference.
  belongs_to :active_organization, class_name: "Organization", optional: true

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  # You can only be "in" an organization you actually belong to.
  validate :active_organization_must_be_a_membership

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

  # Signed sum of the postage wallet, in US cents (#145). Mirrors
  # #credit_balance, on the separate cents-denominated ledger physical mail is
  # charged against. Zero for a user who has never topped up — new users get no
  # postage grant.
  sig { returns(Integer) }
  def postage_balance_cents
    postage_credits.sum(:amount_cents).to_i
  end

  # Debit `cents` from the postage wallet for a piece of mail. Same contract as
  # #spend_credit!: must run inside a transaction, because it locks the user row
  # for the duration of that transaction so two concurrent sends can't both pass
  # the balance check and overdraw the wallet. Raises InsufficientPostageError
  # (rolling back the surrounding transaction) when the balance is short.
  #
  # A non-positive `cents:` is an ArgumentError rather than a silent write: with
  # a signed ledger, a sign error would otherwise turn a charge into a grant.
  sig do
    params(cents: Integer, reason: String, event_kind: String, event_data: T::Hash[T.untyped, T.untyped])
      .returns(PostageCredit)
  end
  def spend_postage!(cents:, reason:, event_kind:, event_data: {})
    raise ArgumentError, "Cents must be positive" unless cents.positive?

    lock!
    raise InsufficientPostageError, "Not enough postage credit" if postage_balance_cents < cents

    postage_credits.create!(
      amount_cents: -cents,
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

  # Put `cents` back into the postage wallet — a refund for mail we failed to
  # send, a promo grant, an admin correction. Always a new positive row: the
  # ledger is append-only, so the negative row a refund answers is left exactly
  # as it was written.
  #
  # No lock and no balance check, unlike #spend_postage!: adding to a balance
  # can't overdraw it.
  sig do
    params(cents: Integer, reason: String, event_kind: String, event_data: T::Hash[T.untyped, T.untyped])
      .returns(PostageCredit)
  end
  def refund_postage!(cents:, reason:, event_kind:, event_data: {})
    raise ArgumentError, "Cents must be positive" unless cents.positive?

    postage_credits.create!(
      amount_cents: cents,
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

  # Checked against the raw column rather than the `active_organization`
  # association: the association is nil for an archived organization, which
  # would make every later save of an otherwise valid user fail. Archiving is
  # not the member's doing, and the membership row survives it.
  sig { void }
  def active_organization_must_be_a_membership
    return if active_organization_id.nil?
    return if organization_memberships.exists?(organization_id: active_organization_id)

    errors.add(:active_organization, "is not an organization you belong to")
  end

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
