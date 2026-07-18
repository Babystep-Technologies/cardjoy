FactoryBot.define do
  factory :user do
    name { "Test User" }
    email { Faker::Internet.email }
    password { "password" }
    email_confirmed { true }

    # Strip the automatic signup grant so a spec can assert on an explicit
    # balance (starts the user at 0 credits).
    trait :without_signup_credits do
      after(:create) do |user|
        user.credits.where(reason: "signup_bonus").destroy_all
      end
    end
  end
end
