# typed: false

# Shared validation for the two credit ledgers: Credit (personal) and
# OrganizationCredit (an organization's shared pool). Both are append-only
# tables carrying an `events` jsonb audit trail, and both need that array to
# stay well formed — otherwise the ledger stops being readable as history.
#
# Each entry must be a hash with an `event_kind` drawn from the including
# model's allowlist, a hash `event_data`, and an ISO 8601 `event_happened_at`.
# The allowlists differ per ledger (a personal `signup_bonus` is meaningless
# for an org pool, and vice versa), so an including model declares its own
# `EVENT_KINDS` constant and returns it from #allowed_event_kinds.
#
# Typed `false` like the other model concerns: the validation calls back into
# ActiveRecord methods (`events`, `errors`) that only exist on the including
# class.
module CreditLedger
  extend ActiveSupport::Concern

  # Timestamps are written with `Time#iso8601(3)`, so milliseconds are required.
  EVENT_HAPPENED_AT_FORMAT = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z\z/

  included do
    validate :events_must_be_array_of_valid_objects
  end

  private

  # Overridden by each including model with its own EVENT_KINDS constant.
  def allowed_event_kinds
    []
  end

  def events_must_be_array_of_valid_objects
    return if events.blank? # allow empty

    unless events.is_a?(Array)
      errors.add(:events, "must be an array")
      return
    end

    events.each_with_index do |event, idx|
      unless event.is_a?(Hash) && event.key?("event_kind") && event.key?("event_data")
        errors.add(:events, "event at index #{idx} must have event_kind and event_data")
        next
      end

      unless allowed_event_kinds.include?(event["event_kind"])
        errors.add(:events, "event_kind '#{event['event_kind']}' at index #{idx} is not allowed")
      end

      unless event["event_data"].is_a?(Hash)
        errors.add(:events, "event_data at index #{idx} must be a hash")
      end

      unless event["event_happened_at"].is_a?(String) && event["event_happened_at"].match?(EVENT_HAPPENED_AT_FORMAT)
        errors.add(:events, "event_happened_at at index #{idx} must be a valid ISO 8601 string")
      end
    end
  end
end
