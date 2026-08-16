# typed: true

# A printed holiday card: a front and a back, each a set of filled photo, text,
# and sticker slots.
#
# This deliberately does not reuse Card. A Card is a single surface — a cover
# image, some styles, and a list of messages — while a holiday card is two
# panels that have to render to print, so it gets its own model the way
# Invitation does.
#
# The slot *geometry* lives in the static template catalogue keyed by
# `template_id`; `design_config` only records what the user chose to put in
# those slots. That split is why adding a template or a sticker never requires
# editing this model — slot and sticker ids are intentionally not validated
# here.
class HolidayCard < ApplicationRecord
  belongs_to :user
  has_many_attached :photos

  # Design-document versions this model understands. Keep old numbers listed
  # when the shape changes so already-stored cards stay valid.
  KNOWN_DESIGN_CONFIG_VERSIONS = [ 1 ].freeze
  CURRENT_DESIGN_CONFIG_VERSION = 1

  # The two panels of the card. Any other top-level panel key is rejected.
  PANELS = %w[front back].freeze

  VALID_SIZES = %w[6x4 6x9].freeze

  # The locked font set, and the single source of truth for it. The print
  # renderer inlines these as base64, so every entry must be webfont-embeddable.
  # The first four match Invitation::VALID_FONTS; the last two are the seasonal
  # serifs.
  VALID_FONTS = %w[poppins playfair montserrat dancing_script cormorant libre_baskerville].freeze

  # `#rrggbb` only — anchored, and deliberately narrow, because these values are
  # interpolated straight into the print renderer's CSS.
  HEX_COLOR_FORMAT = /\A#\h{6}\z/

  # The print area is finite, so a text slot can't hold an essay.
  TEXT_CONTENT_MAX_LENGTH = 500

  # How far a photo may be scaled inside its slot. Below 1.0 it stops filling
  # the slot; far above it there is nothing left to see.
  MIN_ZOOM = 0.5
  MAX_ZOOM = 5.0

  validates :external_id, presence: true, uniqueness: true, format: { with: /\A[A-Z]{7}\z/ }
  validates :size, inclusion: { in: VALID_SIZES }
  validates :template_id, presence: true
  validates :title, length: { maximum: 255 }, allow_blank: true
  validates :photos, content_type: { in: %w[image/png image/jpeg image/gif], message: "must be a valid image format" },
    size: { less_than: 10.megabytes, message: "must be less than 10MB" },
    if: :photos_attached?

  validate :design_config_structure

  before_validation :generate_external_id, on: :create

  default_scope { where(deleted_at: nil) }

  def delete!; update!(deleted_at: Time.current); end
  def restore!; update!(deleted_at: nil); end
  def deleted; deleted_at.present?; end

  # The blob ids `design_config` is allowed to reference: this card's own
  # photos, and nothing else.
  #
  # A blob staged by `photos.attach` but not yet saved has no id, so it is not
  # referenceable in the same save. That is fine for the intended flow — the
  # client uploads photos, gets their blob ids back, and only then places them
  # in a slot.
  def attached_photo_blob_ids
    photos.blobs.map(&:id).compact
  end

  def photo_url(blob)
    return "#{Rails.configuration.x.cdn_host}/#{blob.key}" if Rails.configuration.x.cdn_enabled

    Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: false)
  end

  private

  def photos_attached?
    photos.attached?
  end

  def generate_external_id
    # Only capital letters A-Z, mirroring Card#generate_external_id.
    # T.unsafe: Sorbet doesn't understand this runs in before_validation where
    # external_id may be nil.
    T.unsafe(self).external_id ||= T.cast(Array("A".."Z").sample(7), T::Array[String]).join
  end

  # Validates the design document. Follows Invitation#opening_message_config_structure:
  # every failure adds to errors[:design_config] with a specific message and
  # nothing ever raises, so a malformed document from a client is a 422 rather
  # than a 500.
  def design_config_structure
    return if design_config.blank?

    unless design_config.is_a?(Hash)
      errors.add(:design_config, "must be an object")
      return
    end

    config = design_config.with_indifferent_access

    unless KNOWN_DESIGN_CONFIG_VERSIONS.include?(config[:version])
      errors.add(:design_config, "has an unknown version")
      return
    end

    blob_ids = attached_photo_blob_ids

    config.except(:version).each do |panel_name, panel|
      unless PANELS.include?(panel_name.to_s)
        errors.add(:design_config, "has an unknown panel #{panel_name}")
        next
      end

      unless panel.is_a?(Hash)
        errors.add(:design_config, "panel #{panel_name} must be an object")
        next
      end

      validate_panel_photos(panel_name, panel[:photos], blob_ids)
      validate_panel_texts(panel_name, panel[:texts])

      # Only the shape is checked. Sticker ids and regions are catalogue
      # entries, so validating them here would mean editing this model every
      # time a sticker is added.
      stickers = panel[:stickers]
      if stickers.present? && !stickers.is_a?(Array)
        errors.add(:design_config, "stickers in panel #{panel_name} must be a list")
      end
    end
  end

  def validate_panel_photos(panel_name, photos_config, blob_ids)
    return if photos_config.blank?

    unless photos_config.is_a?(Hash)
      errors.add(:design_config, "photos in panel #{panel_name} must be an object")
      return
    end

    photos_config.each do |slot_id, photo|
      unless photo.is_a?(Hash)
        errors.add(:design_config, "photo #{slot_id} in panel #{panel_name} must be an object")
        next
      end

      unless blob_ids.include?(photo[:blob_id])
        errors.add(:design_config, "photo #{slot_id} in panel #{panel_name} references a photo that is not attached to this card")
      end

      zoom = photo[:zoom]
      if zoom.present? && !(zoom.is_a?(Numeric) && zoom.between?(MIN_ZOOM, MAX_ZOOM))
        errors.add(:design_config, "photo #{slot_id} in panel #{panel_name} has a zoom outside #{MIN_ZOOM}–#{MAX_ZOOM}")
      end

      %i[pan_x pan_y].each do |key|
        value = photo[key]
        next if value.blank? || value.is_a?(Numeric)

        errors.add(:design_config, "photo #{slot_id} in panel #{panel_name} has a non-numeric #{key}")
      end
    end
  end

  def validate_panel_texts(panel_name, texts_config)
    return if texts_config.blank?

    unless texts_config.is_a?(Hash)
      errors.add(:design_config, "texts in panel #{panel_name} must be an object")
      return
    end

    texts_config.each do |slot_id, text|
      unless text.is_a?(Hash)
        errors.add(:design_config, "text #{slot_id} in panel #{panel_name} must be an object")
        next
      end

      content = text[:content]
      if content.present? && content.to_s.length > TEXT_CONTENT_MAX_LENGTH
        errors.add(:design_config, "text #{slot_id} in panel #{panel_name} is longer than #{TEXT_CONTENT_MAX_LENGTH} characters")
      end

      font = text[:font]
      if font.present? && !VALID_FONTS.include?(font)
        errors.add(:design_config, "text #{slot_id} in panel #{panel_name} has an invalid font")
      end

      color = text[:color]
      if color.present? && !color.to_s.match?(HEX_COLOR_FORMAT)
        errors.add(:design_config, "text #{slot_id} in panel #{panel_name} has an invalid color")
      end
    end
  end
end
