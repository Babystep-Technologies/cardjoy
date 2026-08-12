# typed: true

# Proactively nudges a user ~a week before one of their occasion-book occasions
# so they can send a scheduled, thoughtful card instead of a rushed same-day
# text (issue #28). The email names the person and occasion, suggests a curated
# design, and deep-links into the pre-filled 1-on-1 create flow (issue #29).
class OccasionReminderMailer < ApplicationMailer
  extend T::Sig

  def upcoming_occasion(occasion)
    @occasion = occasion
    @contact = occasion.contact
    @user = @contact.user
    # Occasions belong to a contact, not an organization, so there is no owning
    # organization to read. The reminder is branded by the organization the
    # recipient is currently acting in, because that is the context the card
    # they're being nudged to send will be created in (#123).
    set_organization_brand(@user.active_organization)
    @occurrence = occasion.next_occurrence
    @days_away = (@occurrence - Date.current).to_i
    @suggestion = OccasionDesignSuggestion.for(occasion.kind)
    @create_url = create_flow_url(occasion)

    mail(
      to: @user.email,
      subject: "#{@contact.name}'s #{@occasion.kind} is #{days_away_phrase(@days_away)} — send a card",
      **brand_reply_to
    )
  end

  private

  # Deep link into the pre-filled 1-on-1 create flow (issue #29). The flow reads
  # `recipient`, `occasion`, `effect` (the curated design's effect slug) and
  # `deliverAt` (the occasion's calendar date) to pre-select the design and
  # pre-fill the recipient, occasion, and scheduled send — the user only writes
  # the message and confirms. Every pre-filled field stays editable.
  sig { params(occasion: Occasion).returns(String) }
  def create_flow_url(occasion)
    base = Rails.application.credentials.dig(:frontend_url)
    suggestion = OccasionDesignSuggestion.for(occasion.kind)
    query = {
      occasion: occasion.kind,
      recipient: T.must(occasion.contact).name,
      deliverAt: occasion.next_occurrence.iso8601
    }
    query[:effect] = suggestion.effect if suggestion.effect
    "#{base}/one-on-one-card/new?#{query.to_query}"
  end

  sig { params(days: Integer).returns(String) }
  def days_away_phrase(days)
    case days
    when ..0 then "today"
    when 1 then "tomorrow"
    else "in #{days} days"
    end
  end
end
