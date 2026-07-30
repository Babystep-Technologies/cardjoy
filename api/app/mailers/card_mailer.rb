# typed: true

class CardMailer < ApplicationMailer
  def collaborator_invite(email, card)
    @card = card
    @shared_url = "#{Rails.application.credentials.dig(:frontend_url)}/card/#{@card.external_id}/editable"
    mail(to: email, subject: "You're invited to collaborate on a CardJoy card!")
  end

  def viewer_invite(email, card)
    @card = card
    @shared_url = viewable_preview_url(card)
    mail(to: email, subject: "You've received a CardJoy card!")
  end

  def one_on_one_delivery(email, card)
    @card = card
    @shared_url = viewable_preview_url(card)
    mail(to: email, subject: "Someone sent you a CardJoy card!")
  end

  private

  # Recipients forward these links into group chats, so they need to unfurl with the
  # card's own title and image. The SPA can't do that — its index.html is static — so
  # point at the API's server-rendered preview, which redirects on to the same page.
  def viewable_preview_url(card)
    Rails.application.routes.url_helpers.viewable_card_preview_url(id: card.external_id)
  end
end
