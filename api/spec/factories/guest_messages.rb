FactoryBot.define do
  factory :guest_message do
    association :card
    title { "Sample Title" }
    text { "Sample text for the message." }
  end
end
