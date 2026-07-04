FactoryBot.define do
  factory :admin do
    email { Faker::Internet.email }
    name { Faker::Name.name }
    google_uid { Faker::Alphanumeric.alphanumeric(number: 10) }
  end
end
