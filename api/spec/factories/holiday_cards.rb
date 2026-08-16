FactoryBot.define do
  factory :holiday_card do
    user { association :user }
    title { "Shen family 2026" }
    size { "6x4" }
    # A real id from config/holiday_card_templates.yml, matching `size` above —
    # CreateHolidayCard checks both against the catalogue.
    template_id { "snowy_trio" }
    # A fresh card has no content yet; external_id is generated on create.
    design_config { {} }
  end
end
