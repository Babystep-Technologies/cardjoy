FactoryBot.define do
  factory :annual_goal do
    sequence(:year) { |n| 2026 + n }
    dau_target { 1000 }
    cards_and_invitations_target { 5000 }
  end
end
