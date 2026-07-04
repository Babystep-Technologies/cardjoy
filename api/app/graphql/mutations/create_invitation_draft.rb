# typed: true
# frozen_string_literal: true

module Mutations
  class CreateInvitationDraft < BaseMutation
    argument :prompt, String, required: false
    argument :preview_title, String, required: false
    argument :preview_message, String, required: false
    argument :preview_event_date, String, required: false
    argument :preview_event_time, String, required: false
    argument :preview_location, String, required: false
    argument :ai_payload, GraphQL::Types::JSON, required: false

    field :draft, Types::InvitationDraftType, null: true
    field :errors, [ String ], null: false

    def resolve(prompt: nil, preview_title: nil, preview_message: nil, preview_event_date: nil, preview_event_time: nil, preview_location: nil, ai_payload: nil)
      user = context[:current_user]
      return { draft: nil, errors: [ "You must be signed in" ] } unless user

      # If an ai_payload is provided directly, use it. Otherwise call the AI generator service.
      if ai_payload.present?
        payload = ai_payload
        # T.unsafe: payload is JSON that could have string or symbol keys
        unsafe_payload = T.unsafe(payload)
        preview = {
          preview_title: preview_title || payload.dig("content", "title") || unsafe_payload.dig(:content, :title),
          preview_message: preview_message || payload.dig("content", "message") || unsafe_payload.dig(:content, :message),
          preview_event_date: preview_event_date || payload.dig("content", "event_date") || unsafe_payload.dig(:content, :event_date),
          preview_event_time: preview_event_time || payload.dig("content", "event_time") || unsafe_payload.dig(:content, :event_time),
          preview_location: preview_location || payload.dig("content", "location") || unsafe_payload.dig(:content, :location)
        }
      else
        generator = Ai::InvitationDraftGenerator.new(user: user, prompt: prompt, options: {})
        result = generator.generate
        payload = result[:ai_payload]
        preview = {
          preview_title: result[:preview_title],
          preview_message: result[:preview_message],
          preview_event_date: result[:preview_event_date],
          preview_event_time: result[:preview_event_time],
          preview_location: result[:preview_location]
        }
      end

      # Return a transient DTO rather than persisting. Use InvitationDraft (Struct-based) for simplicity.
      draft_obj = InvitationDraft.new(
        external_id: SecureRandom.uuid,
        preview_title: preview[:preview_title],
        preview_message: preview[:preview_message],
        preview_event_date: Date.parse(preview[:preview_event_date]),
        preview_event_time: preview[:preview_event_time],
        preview_location: preview[:preview_location],
        ai_payload: payload,
        status: "pending",
        user: user
      )

      { draft: draft_obj, errors: [] }
    end
  end
end
