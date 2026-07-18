FactoryBot.define do
  factory :occasion do
    kind { "Birthday" }
    occurs_on { Date.new(1990, 6, 15) }
    recurring { true }
    contact

    trait :non_recurring do
      recurring { false }
      occurs_on { Date.current + 5.days }
    end
  end
end
