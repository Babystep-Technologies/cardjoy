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

  # Ceiling on attached photos, so a card cannot be used as an unbounded
  # uploader. Comfortably above the busiest template (six slots across both
  # panels) so someone can upload alternatives and pick between them.
  #
  # Enforced in Mutations::UploadHolidayCardPhoto rather than as a validation
  # here on purpose: a validation would refuse to save an over-cap card, which
  # would also block the delete that is the only way back under the cap.
  MAX_PHOTOS = 20

  # Everything the printed card looks like. A proof is only a valid picture of
  # this card while all three are unchanged: `design_config` is the content,
  # `template_id` the geometry, and `size` the paper.
  #
  # Photo *bytes* are deliberately not in here. Replacing a photo means
  # replacing the blob, which changes the blob id in `design_config` — so a swap
  # already moves the digest, and hashing the attachments as well would mean a
  # database round-trip on every currency check.
  PROOF_DESIGN_FIELDS = %i[design_config template_id size].freeze

  # How long a generated proof is trusted. PostGrid's rendered PDF links are not
  # permanent, so past this window we report the proof as not current and
  # regenerate rather than sending the user to a dead URL. Conservative on
  # purpose: a needless re-render is free (test mode), and a broken proof link
  # at the moment someone is about to spend money is not.
  PROOF_MAX_AGE = 24.hours

  validates :external_id, presence: true, uniqueness: true, format: { with: /\A[A-Z]{7}\z/ }
  validates :size, inclusion: { in: VALID_SIZES }
  validates :template_id, presence: true
  validates :title, length: { maximum: 255 }, allow_blank: true
  validates :photos, content_type: { in: %w[image/png image/jpeg image/gif], message: "must be a valid image format" },
    size: { less_than: 10.megabytes, message: "must be less than 10MB" },
    if: :photos_attached?

  validate :design_config_structure

  before_validation :generate_external_id, on: :create
  # In a callback rather than in the update mutation, so *every* path is
  # covered — the mutations, the console, a future bulk edit. Mirrors
  # Contact#clear_address_verification, and for the same reason: an approval
  # that outlives the design it approved is worse than no approval, because it
  # is the signal the send flow spends money on.
  before_save :clear_proof_approval, if: :proof_design_changing?

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

  # ------------------------------------------------------------------- proof

  # A fingerprint of everything that decides what the printed card looks like.
  #
  # Canonicalized before hashing — keys sorted, all of them strings — because
  # the same design reaches us in more than one shape: symbol keys from a
  # console edit, string keys back from jsonb, and hash insertion order that
  # follows whatever the editor happened to send. None of those is a design
  # change, and a digest that moved when they varied would invalidate proofs
  # for no reason the user could see.
  def proof_design_digest_for_current_design
    payload = PROOF_DESIGN_FIELDS.index_with { |field| canonicalize(public_send(field)) }
    Digest::SHA256.hexdigest(JSON.generate(payload))
  end

  # Whether the stored proof is still a picture of this card — the question the
  # send flow (#148) gates on.
  #
  # Three ways to be false, and they are all the same failure from the user's
  # side ("regenerate the proof"): there is no proof, the design has moved since
  # it was rendered, or the PDF link is old enough that PostGrid may have
  # expired it.
  def proof_current?
    generated_at = proof_generated_at
    return false if proof_url.blank? || generated_at.nil? || proof_design_digest.blank?
    return false if generated_at < PROOF_MAX_AGE.ago

    proof_design_digest == proof_design_digest_for_current_design
  end

  # Approval only counts while the proof it was given to is still current.
  # `clear_proof_approval` already nils `proof_approved_at` on an edit; this is
  # the second lock, and it is the one that catches expiry — a proof that simply
  # aged out is never edited, so no callback fires for it.
  def proof_approved?
    proof_approved_at.present? && proof_current?
  end

  private

  def photos_attached?
    photos.attached?
  end

  # Sorted string keys, all the way down. Arrays keep their order — a sticker
  # list is a paint order, so reordering it *is* a design change.
  def canonicalize(value)
    case value
    when Hash then value.to_h { |key, nested| [ key.to_s, canonicalize(nested) ] }.sort.to_h
    when Array then value.map { |element| canonicalize(element) }
    else value
    end
  end

  def proof_design_changing?
    PROOF_DESIGN_FIELDS.any? { |field| public_send(:"#{field}_changed?") }
  end

  # Only the approval. The URL and its digest survive an edit on purpose: they
  # are what `proof_current?` compares against to *say* the proof is stale, and
  # they let the editor keep showing the last render while a new one is made.
  def clear_proof_approval
    self.proof_approved_at = nil
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

      # Compared as strings: blob ids reach a client as GraphQL `ID` scalars,
      # which serialize to strings, so a document round-tripped through the
      # editor may carry "42" where the database holds 42. Both name the same
      # photo, and rejecting one of them would make an unbuildable card.
      unless blob_ids.map(&:to_s).include?(photo[:blob_id].to_s)
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
