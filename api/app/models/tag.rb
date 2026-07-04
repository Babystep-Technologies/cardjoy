# typed: true

class Tag < ApplicationRecord
  has_many :style_tags, dependent: :destroy
  has_many :styles, through: :style_tags
end
