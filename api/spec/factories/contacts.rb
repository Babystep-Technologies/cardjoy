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

    # A contact carrying a cached PostGrid verdict, so a spec can exercise
    # pricing without a verification round trip.
    #
    # It has to be an after(:create) update rather than plain attributes:
    # Contact clears its verification columns in a before_save whenever an
    # address field changes, and on create every address field is "changing".
    trait :address_verified do
      mailable

      transient do
        zone { PostGrid::AddressVerification::ZONE_US_DOMESTIC }
        verification_status { Contact::VERIFIED_STATUS }
      end

      after(:create) do |contact, evaluator|
        contact.update!(
          address_verified_at: Time.current,
          address_verification_status: evaluator.verification_status,
          address_zone: evaluator.zone
        )
      end
    end

    trait :with_occasions do
      after(:create) do |contact|
        create_list(:occasion, 2, contact: contact)
      end
    end
  end
end
