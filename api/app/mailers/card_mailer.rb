# typed: true

class CardMailer < ApplicationMailer
  def collaborator_invite(email, card)
    @card = card
    @shared_url = "#{Rails.application.credentials.dig(:frontend_url)}/card/#{@card.external_id}/editable"
    mail(to: email, subject: "You're invited to collaborate on a CardJoy card!")
  end

  def viewer_invite(email, card)
    @card = card
    @shared_url = "#{Rails.application.credentials.dig(:frontend_url)}/card/#{@card.external_id}/viewable"
    mail(to: email, subject: "You've received a CardJoy card!")
  end

  def one_on_one_delivery(email, card)
    @card = card
    @shared_url = "#{Rails.application.credentials.dig(:frontend_url)}/card/#{@card.external_id}/viewable"
    mail(to: email, subject: "Someone sent you a CardJoy card!")
  end
end
