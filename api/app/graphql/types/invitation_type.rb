# typed: true
# frozen_string_literal: true

module Types
  class InvitationType < Types::BaseObject
    field :id, ID, null: false
    field :external_id, String, null: false
    field :slug, String, null: true
    field :title, String, null: false
    field :description, String, null: true
    field :location, String, null: true
    field :event_date, GraphQL::Types::ISO8601Date, null: false
    field :event_time, String, null: false
    field :event_timezone, String, null: true
    field :rsvp_deadline, GraphQL::Types::ISO8601Date, null: true
    field :cover_image_url, String, null: true
    field :max_additional_guests, Integer, null: false
    field :attire, String, null: true
    field :custom_instructions, String, null: true
    field :opening_message, String, null: true
    field :opening_message_config, Types::OpeningMessageConfigType, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :user, Types::UserType, null: false
    # The organization that owns this invitation; null means it is personal.
    field :organization, Types::OrganizationType, null: true
    field :rsvps, [ Types::RsvpType ], null: false
    field :rsvp_counts, Types::RsvpCountsType, null: false
    field :wish_list, Types::WishListType, null: true

    # A hidden wish list stays visible to the host so they can build it before publishing.
    def wish_list
      list = object.wish_list
      return nil if list.nil?
      return list if list.visible

      viewer = context[:current_user]
      viewer && viewer.id == object.user_id ? list : nil
    end

    def rsvp_counts
      rsvps = object.rsvps
      going_rsvps = rsvps.going
      additional_guests_total = going_rsvps.sum(:additional_guests_count)

      {
        going: going_rsvps.count,
        maybe: rsvps.maybe.count,
        not_going: rsvps.not_going.count,
        total: rsvps.count,
        total_attendees: going_rsvps.count + additional_guests_total
      }
    end

    def max_additional_guests
      object.max_additional_guests || 1
    end

    def cover_image_url
      return object.cover_image_url if object.cover_image_url.present?
      return nil unless object.cover_image.attached?

      Rails.application.routes.url_helpers.rails_blob_url(object.cover_image, only_path: false)
    end

    def opening_message_config
      return object.opening_message_config if object.opening_message_config.present?

      # Backward compatibility: generate default config from legacy opening_message
      return nil unless object.opening_message.present?

      {
        "template_id" => "classic_centered",
        "text" => { "title" => object.opening_message, "subtitle" => nil },
        "theme" => { "font" => "poppins", "text_color" => "#FFFFFF" },
        "background" => { "type" => "gradient", "value" => "from-purple-400 via-pink-400 to-blue-400", "overlay_opacity" => 0.0 },
        "animation" => { "preset" => "fade_in", "duration_ms" => 1800 }
      }
    end
  end
end
