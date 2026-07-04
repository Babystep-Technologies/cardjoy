FactoryBot.define do
  factory :rsvp do
    invitation
    user { nil }
    guest_name { "Test Guest" }
    sequence(:guest_email) { |n| "guest#{n}@example.com" }
    status { "going" }
    plus_one { false }
    plus_one_name { nil }
    message { nil }
  end
end
