# typed: true

class Credit < ApplicationRecord
  belongs_to :user

  scope :available, -> { where("amount > 0") }

  EVENT_KINDS = %w[
    card_created
    credit_purchased
    credit_redeemed
    promo_code_redeemed
    credit_reversed_due_to_chargeback
  ].freeze

  validate :events_must_be_array_of_valid_objects

  private

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

      unless EVENT_KINDS.include?(event["event_kind"])
        errors.add(:events, "event_kind '#{event['event_kind']}' at index #{idx} is not allowed")
      end

      unless event["event_data"].is_a?(Hash)
        errors.add(:events, "event_data at index #{idx} must be a hash")
      end

      unless event["event_happened_at"].is_a?(String) && event["event_happened_at"].match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z\z/)
        errors.add(:events, "event_happened_at at index #{idx} must be a valid ISO 8601 string")
      end
    end
  end
end
