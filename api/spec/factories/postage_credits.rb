FactoryBot.define do
  factory :postage_credit do
    user { create(:user) }
    amount_cents { 100 }
    reason { "postage_purchased" }
    events { nil }
  end
end
