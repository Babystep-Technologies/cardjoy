FactoryBot.define do
  factory :card do
    title { "Test Card" }
    recipients { "John Doe, Joan Doe" }
    kind { "group" }
    user

    external_id { Array('A'..'Z').sample(7).join }

    trait :one_on_one do
      kind { "one_on_one" }
    end

    trait :with_messages do
      after(:create) do |card|
        create_list(:message, 3, card: card)
      end
    end

    trait :with_tags do
      after(:create) do |card|
        card.tags << create_list(:tag, 3)
      end
    end

    trait :with_style do
      styles { [ create(:style) ] }
    end
  end
end
