FactoryBot.define do
  factory :promo_code do
    sequence(:code) { |n| "PROMO#{n}" }
    credit_amount { 10 }
    expires_at { 1.week.from_now }
    usage_limit { 100 }
    times_redeemed { 0 }
    user_id { nil }

    trait :user_specific do
      association :user
      usage_limit { 1 }
    end

    trait :expired do
      expires_at { 1.week.ago }
    end

    trait :limit_reached do
      usage_limit { 1 }
      times_redeemed { 1 }
    end
  end
end
