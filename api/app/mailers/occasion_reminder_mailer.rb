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
    @occurrence = occasion.next_occurrence
    @days_away = (@occurrence - Date.current).to_i
    @suggestion = OccasionDesignSuggestion.for(occasion.kind)
    @create_url = create_flow_url(occasion)

    mail(
      to: @user.email,
      subject: "#{@contact.name}'s #{@occasion.kind} is #{days_away_phrase(@days_away)} — send a card"
    )
  end

  private

  # Deep link into the pre-filled 1-on-1 create flow. The flow already reads the
  # `occasion` query param; `recipient` is consumed once #29 lands.
  sig { params(occasion: Occasion).returns(String) }
  def create_flow_url(occasion)
    base = Rails.application.credentials.dig(:frontend_url)
    query = { occasion: occasion.kind, recipient: T.must(occasion.contact).name }.to_query
    "#{base}/one-on-one-card/new?#{query}"
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
