# typed: true

class Card < ApplicationRecord
  belongs_to :user
  has_many :card_styles, dependent: :destroy
  has_many :styles, through: :card_styles
  has_many :messages, dependent: :destroy
  has_many :guest_messages, dependent: :destroy
  has_one_attached :qr_code
  has_one_attached :cover_image

  KINDS = %w[group one_on_one].freeze

  validates :title, presence: true
  validates :recipients, presence: true
  validates :external_id, presence: true, uniqueness: true, format: { with: /\A[A-Z]{7}\z/ }
  validates :max_messages, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 500 }
  validates :require_login_to_contribute, inclusion: { in: [ true, false ] }
  validates :kind, inclusion: { in: KINDS }
  validates :contributor_prompt, length: { maximum: 500 }, allow_blank: true
  validates :slug, uniqueness: true, allow_nil: true,
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must be lowercase letters, numbers, and hyphens only" },
    length: { minimum: 3, maximum: 100 },
    if: :slug_present?

  before_validation :normalize_slug
  validates :cover_image, content_type: { in: %w[image/png image/jpeg image/gif], message: "must be a valid image format" },
    size: { less_than: 10.megabytes, message: "must be less than 10MB" },
    if: :cover_image_attached?

  before_validation :generate_external_id, on: :create
  before_validation :enforce_one_on_one_defaults
  default_scope { where(deleted_at: nil) }
  OCCASIONS = [
    "Birthday",
    "Wedding",
    "Baby Shower",
    "Retirement",
    "Graduation",
    "Anniversary",
    "New Baby",
    "Engagement",
    "Congratulations",
    "Thank You",
    "Sympathy",
    "Get Well Soon",
    "New Job",
    "Farewell",
    "Holiday",
    "Mother's Day",
    "Father's Day",
    "Valentine's Day",
    "Friendship",
    "Just Because",
    "First day at work",
    "Last day at work",
    "Promotion at work",
    "Work anniversary"
  ].freeze

  def self.paginated(page:, per_page:, search: nil)
    scope = all
    if search.present?
      scope = scope.where("title ILIKE ?", "%#{sanitize_sql_like(search)}%")
    end

    total = scope.count
    offset = (page.to_i - 1) * per_page.to_i
    paginated = scope.order(created_at: :desc).offset(offset).limit(per_page)

    [ paginated, total ]
  end

  def delete!; update!(deleted_at: Time.current); end
  def restore!; update!(deleted_at: nil); end
  def flag!; update!(flagged_at: Time.current); end
  def unflag!; update!(flagged_at: nil); end
  def lock!; update!(locked_at: Time.current); end
  def unlock!; update!(locked_at: nil); end

  def deleted; deleted_at.present?; end
  def flagged; flagged_at.present?; end
  def locked; locked_at.present?; end

  def one_on_one?; kind == "one_on_one"; end
  def group?; kind == "group"; end

  def message_limit_reached?
    messages.count + guest_messages.count >= max_messages
  end
  alias_method :message_limit_reached, :message_limit_reached?

  def qr_code_url
    return nil unless qr_code.attached?
    if Rails.configuration.x.cdn_enabled
      # T.unsafe: Sorbet RBI doesn't know about blob method
      "#{Rails.configuration.x.cdn_host}/#{T.unsafe(qr_code).blob.key}"
    else
      Rails.application.routes.url_helpers.rails_blob_url(qr_code, only_path: false)
    end
  end

  def cover_image_url
    return nil unless cover_image.attached?
    # T.unsafe: Sorbet RBI doesn't know about blob method
    return "#{Rails.configuration.x.cdn_host}/#{T.unsafe(cover_image).blob.key}" if Rails.configuration.x.cdn_enabled
    Rails.application.routes.url_helpers.rails_blob_url(cover_image, only_path: false) if cover_image.attached?
  end

  private

  def generate_external_id
    # Only capital letters A-Z
    # T.unsafe: Sorbet doesn't understand this is called in before_validation where external_id may be nil
    T.unsafe(self).external_id ||= T.cast(Array("A".."Z").sample(7), T::Array[String]).join
  end

  def normalize_slug
    return if slug.blank?
    self.slug = T.must(slug).downcase.strip.gsub(/\s+/, "-").gsub(/[^a-z0-9-]/, "")
  end

  def slug_present?
    slug.present?
  end

  def cover_image_attached?
    cover_image.attached?
  end

  # One-on-one cards have no signing loop, so the login-to-contribute gate never applies.
  def enforce_one_on_one_defaults
    self.require_login_to_contribute = false if one_on_one?
  end
end
