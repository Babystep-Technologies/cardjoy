# typed: true

class StyleTag < ApplicationRecord
  belongs_to :style
  belongs_to :tag
end
