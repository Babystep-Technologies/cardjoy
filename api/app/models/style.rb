# typed: true

class Style < ApplicationRecord
  extend T::Sig
  include HasAttachedImage

  has_many :card_styles, dependent: :destroy
  has_many :cards, through: :card_styles
  has_many :style_tags, dependent: :destroy
  has_many :tags, through: :style_tags
  has_many :collection_styles, dependent: :destroy
  has_many :collections, through: :collection_styles

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: %w[cover background_color text_color] }

  default_scope { where(deleted_at: nil) }
  scope :cover, -> { where(kind: "cover") }

  def archive!
    update!(deleted_at: Time.current)
  end

  def value
    image_url || source
  end
end
