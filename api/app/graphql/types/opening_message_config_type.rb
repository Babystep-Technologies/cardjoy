# typed: true
# frozen_string_literal: true

module Types
  class TextTransformType < Types::BaseObject
    field :x, Float, null: false
    field :y, Float, null: false
    field :rotation, Float, null: false
    field :scale, Float, null: false
  end

  class ImageTransformType < Types::BaseObject
    field :x, Float, null: false
    field :y, Float, null: false
    field :scale, Float, null: false
    field :rotation, Float, null: false
  end

  class OpeningMessageTextType < Types::BaseObject
    field :title, String, null: false
    field :subtitle, String, null: true
    field :transform, TextTransformType, null: true
  end

  class OpeningMessageThemeType < Types::BaseObject
    field :font, String, null: false
    field :text_color, String, null: false
  end

  class OpeningMessageBackgroundType < Types::BaseObject
    field :type, String, null: false
    field :value, String, null: false
    field :overlay_opacity, Float, null: true
    field :image_transform, ImageTransformType, null: true
  end

  class OpeningMessageAnimationType < Types::BaseObject
    field :preset, String, null: false
    field :duration_ms, Integer, null: false
  end

  class OpeningMessageConfigType < Types::BaseObject
    field :template_id, String, null: false
    field :text, OpeningMessageTextType, null: false
    field :theme, OpeningMessageThemeType, null: true
    field :background, OpeningMessageBackgroundType, null: true
    field :animation, OpeningMessageAnimationType, null: true
  end
end
