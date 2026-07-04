# frozen_string_literal: true
# typed: true

# InvitationDraft is a Sorbet-typed DTO for transient (non-persisted) invitation drafts.
# AI generates these drafts, users review them, and then approve to create a real Invitation.
class InvitationDraft < T::Struct
  extend T::Sig

  const :external_id, T.nilable(String)
  const :preview_title, T.nilable(String)
  const :preview_message, T.nilable(String)
  const :preview_event_date, T.nilable(Date)
  const :preview_event_time, T.nilable(String)
  const :preview_location, T.nilable(String)
  const :ai_payload, T.nilable(Hash)
  const :status, T.nilable(String)
  const :created_at, T.nilable(T.any(Time, ActiveSupport::TimeWithZone))
  const :updated_at, T.nilable(T.any(Time, ActiveSupport::TimeWithZone))
  const :user, T.nilable(User)

  sig do
    params(
      external_id: T.nilable(String),
      preview_title: T.nilable(String),
      preview_message: T.nilable(String),
      preview_event_date: T.nilable(Date),
      preview_event_time: T.nilable(String),
      preview_location: T.nilable(String),
      ai_payload: T.nilable(Hash),
      status: T.nilable(String),
      created_at: T.nilable(T.any(Time, ActiveSupport::TimeWithZone)),
      updated_at: T.nilable(T.any(Time, ActiveSupport::TimeWithZone)),
      user: T.nilable(User)
    ).void
  end
  def initialize(
    external_id: nil,
    preview_title: nil,
    preview_message: nil,
    preview_event_date: nil,
    preview_event_time: nil,
    preview_location: nil,
    ai_payload: nil,
    status: "pending",
    created_at: nil,
    updated_at: nil,
    user: nil
  )
    now = Time.current
    super(
      external_id: external_id || SecureRandom.uuid,
      preview_title: preview_title,
      preview_message: preview_message,
      preview_event_date: preview_event_date,
      preview_event_time: preview_event_time,
      preview_location: preview_location,
      ai_payload: ai_payload,
      status: status,
      created_at: created_at || now,
      updated_at: updated_at || now,
      user: user
    )
  end

  # For GraphQL JSON serialization
  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h
    {
      external_id: external_id,
      preview_title: preview_title,
      preview_message: preview_message,
      preview_event_date: preview_event_date,
      preview_event_time: preview_event_time,
      preview_location: preview_location,
      ai_payload: ai_payload,
      status: status,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
