# typed: true

class CardStyle < ApplicationRecord
  belongs_to :card
  belongs_to :style
end
