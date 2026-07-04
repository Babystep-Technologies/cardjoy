# typed: true
# frozen_string_literal: true

module Types
  class RsvpCountsType < Types::BaseObject
    field :going, Integer, null: false, description: "Number of guests attending"
    field :maybe, Integer, null: false, description: "Number of guests who might attend"
    field :not_going, Integer, null: false, description: "Number of guests not attending"
    field :total, Integer, null: false, description: "Total number of RSVPs"
    field :total_attendees, Integer, null: false, description: "Total attendees including plus ones"
  end
end
