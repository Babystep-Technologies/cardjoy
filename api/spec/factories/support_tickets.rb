FactoryBot.define do
  factory :support_ticket do
    user
    external_id { Array('A'..'Z').sample(7).join }
    subject { "Question about my card" }
    category { "Account question" }
    status { "open" }
    last_customer_reply_at { Time.current }

    trait :pending do
      status { "pending" }
    end

    trait :resolved do
      status { "resolved" }
    end

    trait :closed do
      status { "closed" }
    end
  end
end
