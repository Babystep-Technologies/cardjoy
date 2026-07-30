# typed: true

class PreviewsController < ApplicationController
  DEFAULT_OG_IMAGE_URL = "https://cardjoy.app/og-image.png"
  DEFAULT_OG_IMAGE_WIDTH = 1224
  DEFAULT_OG_IMAGE_HEIGHT = 792

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

    # An editable link asks you to sign the card; a viewable link is opened by someone
    # the card was written *for*, so the two need different pitches.
    @title = editable ? card_title_for(@card) : card_viewable_title_for(@card)
    @description = editable ? card_og_description_for(@card) : card_viewable_og_description_for(@card)
    assign_preview_image(@card)
    frontend_url = AppConfig.frontend_url
    card_path = @card.slug.present? ? @card.slug : @card.external_id
    @url = editable ? "#{frontend_url}/card/#{card_path}/editable" : "#{frontend_url}/card/#{card_path}/viewable"

    render "previews/show", layout: false
  end

  def render_invitation_preview(id_or_slug)
    @invitation = find_invitation(id_or_slug)

    @title = invitation_title_for(@invitation)
    @description = invitation_og_description_for(@invitation)
    assign_preview_image(@invitation)
    frontend_url = AppConfig.frontend_url
    @url = "#{frontend_url}/invitation/#{@invitation.external_id}"

    render "previews/show", layout: false
  end

  # Sets the og:image and, when we know them, its dimensions. Unfurl clients use the
  # dimensions to lay the image out before it loads, and previews/show uses them to
  # decide whether a large summary card would crop the image badly.
  def assign_preview_image(record)
    @image_url = record.cover_image_url
    @image_alt = "Cover image for #{@title}"

    if @image_url.present?
      metadata = record.cover_image.blob.metadata
      @image_width = metadata["width"]
      @image_height = metadata["height"]
    else
      @image_url = DEFAULT_OG_IMAGE_URL
      @image_alt = "CardJoy"
      @image_width = DEFAULT_OG_IMAGE_WIDTH
      @image_height = DEFAULT_OG_IMAGE_HEIGHT
    end
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

    case card.occasion
    when "Birthday"
      "Write a message to make #{recipients_name}'s birthday unforgettable 🎂"
    when "Wedding"
      "Share a note to celebrate #{recipients_name}'s wedding day 💍"
    when "Baby Shower", "New Baby"
      "Welcome #{recipients_name}'s little one with a message 👶"
    when "Retirement"
      "Send #{recipients_name} into retirement with a message 🎉"
    when "Graduation"
      "Cheer on #{recipients_name}'s graduation with a message 🎓"
    when "Anniversary"
      "Celebrate #{recipients_name}'s anniversary with a message 💕"
    when "Engagement"
      "Toast #{recipients_name}'s engagement with a message 💍"
    when "Congratulations"
      "Congratulate #{recipients_name} with a heartfelt message 🎉"
    when "Thank You"
      "Say thank you to #{recipients_name} with a message 🙏"
    when "Sympathy"
      "Share a few comforting words with #{recipients_name} 🤍"
    when "Get Well Soon"
      "Send #{recipients_name} get-well wishes with a message 💐"
    when "New Job"
      "Cheer on #{recipients_name}'s new job with a message 🎉"
    when "Farewell"
      "Wish #{recipients_name} a heartfelt farewell 👋"
    when "Holiday"
      "Share some holiday cheer with #{recipients_name} 🎄"
    when "Mother's Day"
      "Celebrate #{recipients_name} this Mother's Day with a message 💐"
    when "Father's Day"
      "Celebrate #{recipients_name} this Father's Day with a message 🎉"
    when "Valentine's Day"
      "Share the love with #{recipients_name} this Valentine's Day 💌"
    when "Friendship"
      "Celebrate your friendship with #{recipients_name} 💛"
    when "Just Because"
      "Brighten #{recipients_name}'s day with a message, just because ✨"
    when nil, ""
      "Write a message for #{recipients_name} 💌"
    else
      "Write #{recipients_name} a message for their #{card.occasion} ✨"
    end
  end

  # Viewable links go to whoever the card is *for*, so the copy invites them to read
  # what's already been written rather than to add a message of their own.
  def card_viewable_title_for(card)
    recipients_name = recipients_phrase(card)

    case card.occasion
    when "Birthday"
      "#{recipients_name} #{has_or_have(card)} a birthday card waiting 🎂"
    when "Wedding"
      "A wedding card for #{recipients_name} 💍"
    when "Baby Shower", "New Baby"
      "A card for #{recipients_name}'s little one 👶"
    when "Retirement"
      "A retirement card for #{recipients_name} 🎉"
    when "Graduation"
      "A graduation card for #{recipients_name} 🎓"
    when "Anniversary"
      "An anniversary card for #{recipients_name} 💕"
    when "Engagement"
      "An engagement card for #{recipients_name} 💍"
    when "Congratulations"
      "A congratulations card for #{recipients_name} 🎉"
    when "Thank You"
      "A thank-you card for #{recipients_name} 🙏"
    when "Sympathy"
      "A card of condolences for #{recipients_name} 🤍"
    when "Get Well Soon"
      "A get-well card for #{recipients_name} 💐"
    when "New Job"
      "A new-job card for #{recipients_name} 🎉"
    when "Farewell"
      "A farewell card for #{recipients_name} 👋"
    when "Holiday"
      "A holiday card for #{recipients_name} 🎄"
    when "Mother's Day"
      "A Mother's Day card for #{recipients_name} 💐"
    when "Father's Day"
      "A Father's Day card for #{recipients_name} 🎉"
    when "Valentine's Day"
      "A Valentine's Day card for #{recipients_name} 💌"
    when "Friendship"
      "A friendship card for #{recipients_name} 💛"
    when "Just Because"
      "A card for #{recipients_name}, just because ✨"
    when nil, ""
      "A card for #{recipients_name} 💌"
    else
      "A card for #{recipients_name}'s #{card.occasion} ✨"
    end
  end

  def card_viewable_og_description_for(card)
    signature_count = card.messages.count + card.guest_messages.count
    # Promising "everyone's messages" before anyone has signed would be a lie.
    return "Open it to take a look." if signature_count.zero?

    "#{signature_count} #{'person'.pluralize(signature_count)} signed it. " \
      "#{card_viewable_read_prompt_for(card)}"
  end

  def card_viewable_read_prompt_for(card)
    case card.occasion
    when "Birthday"
      "Open it to read everyone's birthday wishes."
    when "Farewell"
      "Messages from everyone who wanted to say goodbye."
    when "Sympathy"
      "Kind words from people who are thinking of you."
    when "Thank You"
      "Open it to read everyone's thank-yous."
    when "Congratulations", "Graduation", "New Job", "Retirement"
      "Open it to read everyone's congratulations."
    else
      "Open it to read everyone's messages."
    end
  end

  # "Alice", "Alice & Bob", "Alice, Bob & Carol" — cards can have several recipients.
  def recipients_phrase(card)
    card.recipients.to_sentence(two_words_connector: " & ", last_word_connector: " & ")
  end

  def has_or_have(card)
    card.recipients.size > 1 ? "have" : "has"
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
