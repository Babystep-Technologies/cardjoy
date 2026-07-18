FactoryBot.define do
  factory :contact do
    sequence(:name) { |n| "Contact #{n}" }
    sequence(:email) { |n| "contact#{n}@example.com" }
    relationship { "Friend" }
    user

    trait :with_occasions do
      after(:create) do |contact|
        create_list(:occasion, 2, contact: contact)
      end
    end
  end
end
