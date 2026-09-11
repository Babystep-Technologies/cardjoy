FactoryBot.define do
  factory :user_daily_activity do
    user
    activity_date { Date.current }
  end
end
