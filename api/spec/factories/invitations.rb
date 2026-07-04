FactoryBot.define do
  factory :invitation do
    user { association :user }
    external_id { SecureRandom.uuid }
    title { "Sample Event" }
    description { "Join us for a great time!" }
    location { "123 Main Street" }
    event_date { Date.today + 30.days }
    event_time { "18:00" }
    event_timezone { "America/Los_Angeles" }
    rsvp_deadline { Date.today + 7.days }
    allow_plus_one { false }
    attire { "Casual" }
    custom_instructions { "Please arrive 15 minutes early" }
  end
end
