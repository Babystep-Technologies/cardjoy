FactoryBot.define do
  factory :style do
    name { "Default Style" }
    kind { "cover" }
    source { "/styles/default.jpg" }

    trait :effect do
      name { "Confetti" }
      kind { "effect" }
      source { "confetti" }
    end
  end
end
