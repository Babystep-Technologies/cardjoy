FactoryBot.define do
  factory :slack_installation do
    team_id { "T#{SecureRandom.hex(4).upcase}" }
    team_name { "Test Workspace" }
    access_token { "xoxb-test-token" }
  end
end
