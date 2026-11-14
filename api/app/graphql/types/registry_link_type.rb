# typed: true

module Types
  # The minimum a card needs to point at a registry: enough to render a link-out, nothing about its
  # items. The guest opens the real page to see those.
  class RegistryLinkType < Types::BaseObject
    field :external_id, String, null: false
    field :title, String, null: false
    field :owner_first_name, String, null: true

    # A passcode-protected registry keeps its title behind the passcode, even on a card or invitation
    # that links it.
    def title
      object.passcode_protected? ? "A private registry" : object.title
    end

    def owner_first_name
      object.user&.name.to_s.split.first
    end
  end
end
