# typed: true

class Style < ApplicationRecord
  extend T::Sig
  include HasAttachedImage

  # NULL means the global curated gallery an admin maintains; a value means the
  # asset belongs to one organization and only its members may see it (#124).
  belongs_to :organization, optional: true

  has_many :card_styles, dependent: :destroy
  has_many :cards, through: :card_styles
  has_many :style_tags, dependent: :destroy
  has_many :tags, through: :style_tags
  has_many :collection_styles, dependent: :destroy
  has_many :collections, through: :collection_styles

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: %w[cover background_color text_color effect] }

  default_scope { where(deleted_at: nil) }
  scope :cover, -> { where(kind: "cover") }
  scope :effect, -> { where(kind: "effect") }

  # Everything one context may pick from: the global gallery, plus the given
  # organization's own assets. Passing nil (a Personal context, or a caller who
  # may not read the organization) leaves just the global gallery.
  scope :available_to, ->(organization) { where(organization_id: [ nil, organization&.id ]) }

  def archive!
    update!(deleted_at: Time.current)
  end

  def value
    image_url || source
  end
end
