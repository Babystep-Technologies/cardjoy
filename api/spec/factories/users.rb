FactoryBot.define do
  factory :user do
    name { "Test User" }
    email { Faker::Internet.email }
    password { "password" }
    email_confirmed { true }
  end
end
