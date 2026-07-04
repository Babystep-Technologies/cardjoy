FactoryBot.define do
  factory :style do
    name { "Default Style" }
    kind { "cover" }
    source { "/styles/default.jpg" }
  end
end
