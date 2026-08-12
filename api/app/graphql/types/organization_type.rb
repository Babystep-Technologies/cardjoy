# typed: true

module Types
  class OrganizationType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :slug, String, null: false
    field :description, String, null: true
    field :members_count, Integer, null: false
    field :credit_balance, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # Email branding (#123). All nullable — nil means this organization's mail
    # uses CardJoy's own branding, which is the default and the common case.
    field :logo_url, String, null: true
    field :accent_color, String, null: true
    field :email_footer_text, String, null: true
    field :email_reply_to, String, null: true

    def members_count
      object.organization_memberships.count
    end
  end
end
