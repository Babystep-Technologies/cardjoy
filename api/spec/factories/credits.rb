FactoryBot.define do
  factory :credit do
    user { create(:user) }
    amount { 1 }
    reason { "purchased" }
    events { nil }
  end
end
