# typed: true
# frozen_string_literal: true

module Types
  class CalendarLinksType < Types::BaseObject
    field :google, String, null: false, description: "Google Calendar add event URL"
    field :outlook, String, null: false, description: "Outlook Web Calendar add event URL"
    field :yahoo, String, null: false, description: "Yahoo Calendar add event URL"
    field :ics, String, null: false, description: "ICS file content for download"
  end
end
