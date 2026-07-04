FactoryBot.define do
  factory :slack_user_connection do
    association :user
    slack_user_id { "U#{SecureRandom.hex(4).upcase}" }
    slack_team_id { "T#{SecureRandom.hex(4).upcase}" }
  end
end
