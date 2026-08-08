FactoryBot.define do
  factory :organization_invitation do
    organization
    sequence(:email) { |n| "invitee#{n}@example.com" }
    role { OrganizationMembership::MEMBER }
    invited_by factory: :user

    trait :admin do
      role { OrganizationMembership::ADMIN }
    end

    # `expires_at` is set on create, so an already-lapsed invitation has to be
    # written past the model rather than through it.
    trait :expired do
      after(:create) { |invitation| invitation.update_column(:expires_at, 1.day.ago) }
    end

    trait :accepted do
      status { OrganizationInvitation::ACCEPTED }
      accepted_at { Time.current }
    end

    trait :revoked do
      status { OrganizationInvitation::REVOKED }
    end
  end
end
