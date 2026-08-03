FactoryBot.define do
  factory :wish_list do
    invitation { association :invitation }
    title { "Wish List" }
    intro { "Anything from here would be lovely." }
    visible { true }
    surprise_mode { true }
  end

  factory :wish_list_item do
    wish_list { association :wish_list }
    title { "Wooden play gym" }
    url { "https://lovevery.com/products/play-gym" }
    price { "$140" }
    note { "Any color works" }
    quantity { 1 }
  end

  factory :wish_list_contribution do
    wish_list { association :wish_list }
    kind { WishListContribution::VENMO }
    handle { "@party-host" }
    label { "Toward the crib fund" }
    suggested_amount { "$25" }
  end
end
