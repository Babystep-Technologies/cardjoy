# typed: true

module Mutations
  # "Start a new year" for a recurring registry such as a birthday list (#251): keeps the items,
  # clears last year's claims, and moves the event date forward to its next occurrence. The owner's
  # list survives; the guests' promises don't, and their claim links stop working.
  class ResetRegistry < BaseMutation
    argument :external_id, String, required: true

    field :wish_list, Types::WishListType, null: true
    field :errors, [ String ], null: false

    def resolve(external_id:)
      user = context[:current_user]
      return failure("You must be signed in") unless user

      list = user.wish_lists.find_by(external_id: external_id)
      return failure("Registry not found") unless list
      return failure("Only a standalone registry can be reset") unless list.standalone?

      WishList.transaction do
        WishListReservation.where(wish_list_item_id: list.items.select(:id)).destroy_all
        list.update!(event_date: next_year(list.event_date)) if list.event_date
      end

      { wish_list: list.reload, errors: [] }
    end

    private

    # One year on, and on again until it is actually ahead, so resetting a list that has sat for
    # years doesn't land on a date that has already passed.
    def next_year(date)
      date += 1.year
      date += 1.year while date < Date.current
      date
    end

    def failure(message)
      { wish_list: nil, errors: [ message ] }
    end
  end
end
