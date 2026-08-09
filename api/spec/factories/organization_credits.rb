FactoryBot.define do
  factory :organization_credit do
    organization
    amount { 1 }
    reason { "purchase" }
    events { nil }
  end
end
