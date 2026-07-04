# typed: true
# frozen_string_literal: true

module Types
  class OpeningMessageTextInputType < Types::BaseInputObject
    argument :title, String, required: true
    argument :subtitle, String, required: false
  end

  class OpeningMessageThemeInputType < Types::BaseInputObject
    argument :font, String, required: false, default_value: "poppins"
    argument :text_color, String, required: false, default_value: "#FFFFFF"
  end

  class OpeningMessageBackgroundInputType < Types::BaseInputObject
    argument :type, String, required: true # "color" | "gradient" | "image"
    argument :value, String, required: true
    argument :overlay_opacity, Float, required: false, default_value: 0.4
  end

  class OpeningMessageAnimationInputType < Types::BaseInputObject
    argument :preset, String, required: false, default_value: "fade_in"
    argument :duration_ms, Integer, required: false, default_value: 1800
  end

  class OpeningMessageConfigInputType < Types::BaseInputObject
    argument :template_id, String, required: false, default_value: "classic_centered"
    argument :text, OpeningMessageTextInputType, required: true
    argument :theme, OpeningMessageThemeInputType, required: false
    argument :background, OpeningMessageBackgroundInputType, required: false
    argument :animation, OpeningMessageAnimationInputType, required: false
  end
end
