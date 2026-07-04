# typed: true

class PreviewsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  # Card previews
  def card_editable
    render_card_preview(params[:id], editable: true)
  end

  def card_viewable
    render_card_preview(params[:id], editable: false)
  end

  # Invitation previews
  def invitation_view
    render_invitation_preview(params[:id])
  end

  private

  def render_card_preview(id_or_slug, editable:)
    @card = find_card(id_or_slug)

    @title = card_title_for(@card)
    @description = card_og_description_for(@card)
    @image_url = @card.cover_image_url || "https://cardjoy.app/og-image.png"
    frontend_url = Rails.application.credentials.dig(:frontend_url)
    card_path = @card.slug.present? ? @card.slug : @card.external_id
    @url = editable ? "#{frontend_url}/card/#{card_path}/editable" : "#{frontend_url}/card/#{card_path}/viewable"

    render "previews/show", layout: false
  end

  def render_invitation_preview(id_or_slug)
    @invitation = find_invitation(id_or_slug)

    @title = invitation_title_for(@invitation)
    @description = invitation_og_description_for(@invitation)
    @image_url = @invitation.cover_image_url || "https://cardjoy.app/og-image.png"
    frontend_url = Rails.application.credentials.dig(:frontend_url)
    @url = "#{frontend_url}/invitation/#{@invitation.external_id}"

    render "previews/show", layout: false
  end

  def find_card(id_or_slug)
    # Try to find by slug first, then by external_id
    Card.find_by(slug: id_or_slug) || Card.find_by!(external_id: id_or_slug)
  end

  def find_invitation(id_or_slug)
    # Try to find by slug first, then by external_id
    Invitation.find_by(slug: id_or_slug) || Invitation.find_by!(external_id: id_or_slug)
  end

  def card_title_for(card)
    recipients_name = card.recipients.join(", ")
    base = "Card for #{recipients_name}"
    card.occasion.present? ? "#{base} for #{card.occasion}" : base
  end

  def invitation_title_for(invitation)
    "You're Invited: #{invitation.title}"
  end

  def card_og_description_for(card)
    recipients_name = card.recipients.join(", ")

    case card.occasion
    when "Birthday"
      "Celebrate #{recipients_name}'s birthday with your message!"
    when "Wedding"
      "Send your warm wishes for #{recipients_name}'s wedding day!"
    when "Baby Shower", "New Baby"
      "Share your love for #{recipients_name}'s growing family!"
    when "Retirement"
      "Congratulate #{recipients_name} on their amazing career!"
    when "Graduation"
      "Celebrate #{recipients_name}'s big achievement!"
    when "Anniversary"
      "Send anniversary cheers to #{recipients_name}!"
    when "Engagement"
      "Celebrate #{recipients_name}'s engagement with a heartfelt message!"
    when "Congratulations"
      "Congratulate #{recipients_name} on their special milestone!"
    when "Thank You"
      "Share your gratitude with #{recipients_name}!"
    when "Sympathy"
      "Send your condolences and kind thoughts to #{recipients_name}."
    when "Get Well Soon"
      "Wish #{recipients_name} a speedy recovery!"
    when "New Job"
      "Congratulate #{recipients_name} on their new adventure!"
    when "Farewell"
      "Send farewell wishes to #{recipients_name} as they move on."
    when "Holiday"
      "Share holiday cheer with #{recipients_name}!"
    when "Mother's Day"
      "Send love to #{recipients_name} this Mother's Day!"
    when "Father's Day"
      "Celebrate #{recipients_name} this Father's Day!"
    when "Valentine's Day"
      "Share the love with #{recipients_name} this Valentine's Day!"
    when "Friendship"
      "Celebrate your friendship with #{recipients_name}!"
    when "Just Because"
      "Brighten #{recipients_name}'s day just because!"
    else
      # fallback if occasion is nil or unrecognized
      "Add your message for #{recipients_name}'s special moment!"
    end
  end

  def invitation_og_description_for(invitation)
    date_str = invitation.event_date.strftime("%B %d, %Y")
    time_str = Time.parse(invitation.event_time).strftime("%I:%M %p")

    description = "#{date_str} at #{time_str}"
    description += " - #{invitation.location}" if invitation.location.present?
    description += ". RSVP now!"
    description
  end

  def render_not_found
    head :not_found
  end
end
