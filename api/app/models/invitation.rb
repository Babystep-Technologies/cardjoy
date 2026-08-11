# typed: true

class Invitation < ApplicationRecord
  include OrganizationScoped

  belongs_to :user
  has_many :rsvps, dependent: :destroy
  has_one :wish_list, dependent: :destroy

  has_one_attached :cover_image

  validates :title, presence: true
  validates :event_date, presence: true
  validates :event_time, presence: true
  validates :external_id, presence: true, uniqueness: true
  validates :slug, uniqueness: true, allow_nil: true,
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must be lowercase letters, numbers, and hyphens only" },
    length: { minimum: 3, maximum: 100 },
    if: :slug_present?

  before_validation :normalize_slug

  # Validate event_time format (HH:MM)
  validate :event_time_format
  validate :opening_message_config_structure

  VALID_TEMPLATES = %w[classic_centered bold_left minimal_bottom elegant_split playful_stacked modern_gradient].freeze
  VALID_ANIMATIONS = %w[fade_in typewriter slide_up confetti_pop bounce_in sparkle].freeze
  VALID_FONTS = %w[poppins playfair montserrat dancing_script].freeze
  VALID_BACKGROUND_TYPES = %w[color gradient image].freeze

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

  def cover_image_url
    return nil unless cover_image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(cover_image, only_path: false)
  end

  private

  def slug_present?
    slug.present?
  end

  def normalize_slug
    return if slug.blank?
    self.slug = T.must(slug).downcase.strip.gsub(/\s+/, "-").gsub(/[^a-z0-9-]/, "")
  end

  def event_time_format
    return if event_time.blank?

    unless T.must(event_time).match?(/\A([01]\d|2[0-3]):([0-5]\d)\z/)
      errors.add(:event_time, "must be in HH:MM format (e.g., 14:00)")
    end
  end

  def opening_message_config_structure
    return if opening_message_config.blank?

    config = opening_message_config.with_indifferent_access

    # Validate template_id
    if config[:template_id].present? && !VALID_TEMPLATES.include?(config[:template_id])
      errors.add(:opening_message_config, "has invalid template_id")
    end

    # Validate text structure
    if config[:text].present?
      unless config[:text].is_a?(Hash) && config[:text][:title].present?
        errors.add(:opening_message_config, "text must include a title")
      end
    end

    # Validate theme structure
    if config[:theme].present?
      theme = config[:theme]
      if theme[:font].present? && !VALID_FONTS.include?(theme[:font])
        errors.add(:opening_message_config, "has invalid font")
      end
    end

    # Validate background structure
    if config[:background].present?
      bg = config[:background]
      if bg[:type].present? && !VALID_BACKGROUND_TYPES.include?(bg[:type])
        errors.add(:opening_message_config, "has invalid background type")
      end
    end

    # Validate animation structure
    if config[:animation].present?
      anim = config[:animation]
      if anim[:preset].present? && !VALID_ANIMATIONS.include?(anim[:preset])
        errors.add(:opening_message_config, "has invalid animation preset")
      end
    end
  end
end
