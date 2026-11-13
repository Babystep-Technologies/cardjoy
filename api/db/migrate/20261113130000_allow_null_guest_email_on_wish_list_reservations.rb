# Guest emails are scrubbed a week after the event (#252), while the claim itself, and the guest's
# name for thank-you notes, stays. So the column must be able to go empty.
class AllowNullGuestEmailOnWishListReservations < ActiveRecord::Migration[8.1]
  def change
    change_column_null :wish_list_reservations, :guest_email, true
  end
end
