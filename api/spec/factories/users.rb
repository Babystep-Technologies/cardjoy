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

    # A complete return address (#233). Users have none by default — sending a
    # post card is unavailable until one is set.
    trait :with_return_address do
      return_address_line1 { "123 Market St" }
      return_address_line2 { "Apt 4" }
      return_address_city { "San Francisco" }
      return_address_region { "CA" }
      return_address_postal_code { "94103" }
      return_address_country_code { "US" }
    end
  end
end
