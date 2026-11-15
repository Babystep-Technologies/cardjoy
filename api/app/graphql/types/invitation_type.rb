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
    # Moderation state, matching Types::CardType so one admin component can
    # render either product. `locked` refuses new RSVPs; `flagged` hides the
    # invitation from guests; `deleted` is the soft delete admin calls archive.
    field :locked, Boolean, null: false
    field :flagged, Boolean, null: false
    field :deleted, Boolean, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :user, Types::UserType, null: false
    # The organization that owns this invitation; null means it is personal.
    field :organization, Types::OrganizationType, null: true
    field :rsvps, [ Types::RsvpType ], null: false, description: "Hosts and admins only; empty for everyone else."
    field :viewer_can_edit, Boolean, null: false
    field :rsvp_counts, Types::RsvpCountsType, null: false
    field :wish_list, Types::WishListType, null: true, deprecation_reason: "Use `registry`."
    # A link-out to one of the owner's registries; null unless it is shared, so an invitation never
    # advertises a registry its owner hasn't published.
    field :registry, Types::RegistryLinkType, null: true
    # Host-only: when guests were last reminded and when the next reminder may go (#319).
    field :reminder_sent_at, GraphQL::Types::ISO8601DateTime, null: true
    field :next_reminder_at, GraphQL::Types::ISO8601DateTime, null: true

    def reminder_sent_at
      object.reminder_sent_at if host_viewing?
    end

    def next_reminder_at
      object.next_reminder_at if host_viewing?
    end

    # An invitation no longer owns a wish list: it links a registry (`registry`). Always null; kept
    # only so a web build from before that still loads.
    def wish_list
      nil
    end

    # The guest list holds names and emails, so only the people who run the invitation (its owner,
    # an admin of the owning organization) and CardJoy admins can read it. Everyone else, including
    # a guest with the link, gets an empty list.
    def rsvps
      host_viewing? || context[:current_admin] ? object.rsvps : []
    end

    # Lets the web app show the host's view without guessing from user ids.
    def viewer_can_edit
      host_viewing?
    end

    def host_viewing?
      viewer = context[:current_user]
      !viewer.nil? && object.editable_by?(viewer)
    end

    def registry
      list = object.registry
      list if list&.visible
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
