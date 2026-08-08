FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    description { "A team that sends cards together" }
    created_by factory: :user

    # The creator is an admin everywhere in the product; make that the default
    # so specs don't have to remember to seed one.
    trait :with_admin do
      after(:create) do |organization|
        create(:organization_membership,
               organization: organization,
               user: organization.created_by,
               role: OrganizationMembership::ADMIN)
      end
    end
  end
end
