# typed: true
# frozen_string_literal: true

module Ai
  class InvitationDraftGenerator
    # Simple service that interfaces with an AI provider to generate an invitation draft.
    # For now this is a thin stub that returns a predictable structure. Replace the
    # implementation with real calls to OpenAI/Azure/Anthropic as needed.
    def initialize(user:, prompt:, options: {})
      @user = user
      @prompt = prompt
      @options = options
    end

    # Returns a hash with keys matching the invitation_drafts.ai_payload and preview fields
    def generate
      # Placeholder / deterministic sample. Replace with real AI call.
      title = "You're invited to #{@options[:occasion] || 'a special event'}"
      message = "Hey! We'd love for you to join us. #{(@prompt || '').truncate(200)}"
      date = (@options[:event_date] || Date.tomorrow).to_s
      time = (@options[:event_time] || "18:00")
      location = (@options[:location] || "TBD")

      {
        preview_title: title,
        preview_message: message,
        preview_event_date: date,
        preview_event_time: time,
        preview_location: location,
        ai_payload: {
          generated_at: Time.current.iso8601,
          prompt: @prompt,
          model: @options[:model] || "stub-v1",
          content: {
            title: title,
            message: message,
            event_date: date,
            event_time: time,
            location: location
          }
        }
      }
    end
  end
end
