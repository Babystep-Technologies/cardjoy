FactoryBot.define do
  factory :holiday_card do
    user { association :user }
    title { "Shen family 2026" }
    size { "6x4" }
    template_id { "classic_frame" }
    # A fresh card has no content yet; external_id is generated on create.
    design_config { {} }
  end
end
