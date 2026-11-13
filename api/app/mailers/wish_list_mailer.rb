# typed: false

# Mail to the guests of a registry or wish list about the things they claimed (#248). Branded by
# whoever owns the list: the organization for an organization's invitation, CardJoy otherwise.
class WishListMailer < ApplicationMailer
  def claim_confirmation(reservation)
    prepare_claim(reservation)

    mail(
      to: reservation.guest_email,
      subject: "You're getting #{@item.title}",
      **brand_reply_to
    )
  end

  def claim_reminder(reservation)
    prepare_claim(reservation)
    @release_in_days = WishListReservation::RELEASE_AFTER_REMINDER.in_days.to_i

    mail(
      to: reservation.guest_email,
      subject: "Did you get #{@item.title}?",
      **brand_reply_to
    )
  end

  # The reservation is already destroyed by the time this is delivered, so the job passes plain
  # values instead of the record.
  def claim_released(guest_name:, guest_email:, item_title:, wish_list:)
    @guest_name = guest_name
    @item_title = item_title
    @wish_list = wish_list
    set_organization_brand(wish_list.invitation&.owning_organization)
    @list_url = "#{frontend_url}#{wish_list.guest_path}"

    mail(
      to: guest_email,
      subject: "We've freed up #{item_title}",
      **brand_reply_to
    )
  end

  # To the registry's owner, ahead of the event (#251): the nudge to share it. Differs by whether
  # it is already shared, since an unpublished registry has nobody to see it yet.
  def event_reminder(wish_list)
    @wish_list = wish_list
    @owner = wish_list.user
    @days_away = (wish_list.event_date - Date.current).to_i
    @edit_url = "#{frontend_url}/registry/#{wish_list.external_id}/edit"
    @list_url = "#{frontend_url}#{wish_list.guest_path}"
    set_organization_brand(@owner.active_organization)

    mail(
      to: @owner.email,
      subject: "#{@wish_list.title} is #{@days_away.zero? ? 'today' : "in #{@days_away} days"}",
      **brand_reply_to
    )
  end

  private

  def prepare_claim(reservation)
    @reservation = reservation
    @item = reservation.wish_list_item
    @wish_list = @item.wish_list
    set_organization_brand(@wish_list.invitation&.owning_organization)
    # `claim` carries the bearer token so the link works from any browser, not just the one that made
    # the claim. Treat this email like the token itself: anyone holding it can manage the claim.
    @manage_url = "#{frontend_url}#{@wish_list.guest_path}?claim=#{reservation.token}"
  end

  def frontend_url
    Rails.application.credentials.dig(:frontend_url)
  end
end
