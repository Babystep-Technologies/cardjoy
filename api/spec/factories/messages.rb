FactoryBot.define do
  factory :message do
    title { "Sample Title" }
    text { "Sample text for the message." }
    association :card
    association :user

    trait :with_deleted_at do
      deleted_at { Time.current }
    end

    trait :without_deleted_at do
      deleted_at { nil }
    end

    factory :deleted_message, traits: [ :with_deleted_at ]
    factory :active_message, traits: [ :without_deleted_at ]
  end
end
