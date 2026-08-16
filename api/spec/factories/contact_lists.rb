FactoryBot.define do
  factory :contact_list do
    sequence(:name) { |n| "List #{n}" }
    user
  end

  # Both sides default to the *same* user, since a membership across two users
  # is precisely what ContactListMembership refuses to save.
  factory :contact_list_membership do
    contact_list
    contact { association :contact, user: contact_list.user }
  end
end
