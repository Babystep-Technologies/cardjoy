FactoryBot.define do
  factory :support_ticket_message do
    support_ticket
    author_kind { "customer" }
    author_id { support_ticket.user_id }
    body { "Here's the problem I'm running into." }

    trait :admin do
      author_kind { "admin" }
      author_id { create(:admin).id }
    end

    trait :system do
      author_kind { "system" }
      author_id { nil }
    end
  end
end
