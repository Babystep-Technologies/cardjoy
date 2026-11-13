FactoryBot.define do
  factory :contact do
    sequence(:name) { |n| "Contact #{n}" }
    sequence(:email) { |n| "contact#{n}@example.com" }
    relationship { "Friend" }
    user

    # A complete, deliverable address. Contacts have none by default — most never will.
    trait :mailable do
      address_line1 { "123 Market St" }
      address_line2 { "Apt 4" }
      city { "San Francisco" }
      region { "CA" }
      postal_code { "94103" }
      country_code { "US" }
    end

    trait :with_occasions do
      after(:create) do |contact|
        create_list(:occasion, 2, contact: contact)
      end
    end
  end
end
