FactoryBot.define do
  factory :organization_membership do
    organization
    user
    role { OrganizationMembership::MEMBER }

    trait :admin do
      role { OrganizationMembership::ADMIN }
    end
  end
end
