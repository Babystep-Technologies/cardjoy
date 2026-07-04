# typed: false

module HasAttachedImage
  extend ActiveSupport::Concern

  included do
    has_one_attached :image
    validates :image, content_type: { in: %w[image/png image/jpeg image/gif], message: "must be a valid image format" },
      size: { less_than: 10.megabytes, message: "must be less than 10MB" },
      if: -> { image.attached? }
  end

  def image_url
    return nil unless image.attached?
    return "#{Rails.configuration.x.cdn_host}/#{image.key}" if Rails.configuration.x.cdn_enabled
    Rails.application.routes.url_helpers.rails_blob_url(image, only_path: false) if image.attached?
  end
end
