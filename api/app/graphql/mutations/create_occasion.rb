# typed: true

module Mutations
  class CreateOccasion < BaseMutation
    argument :contact_id, ID, required: true
    argument :kind, String, required: true
    argument :occurs_on, GraphQL::Types::ISO8601Date, required: true
    argument :recurring, Boolean, required: false
    # Days before the occasion to send its reminder. Omit to take the default
    # (a week ahead); pass null explicitly to create it with reminders off.
    argument :reminder_lead_days, Integer, required: false

    field :occasion, Types::OccasionType, null: true
    field :errors, [ String ], null: false

    def resolve(contact_id:, kind:, occurs_on:, recurring: nil, **rest)
      user = context[:current_user]
      return { occasion: nil, errors: [ "Not authenticated" ] } unless user

      contact = user.contacts.find_by(id: contact_id)
      return { occasion: nil, errors: [ "Contact not found or not owned by user" ] } unless contact

      occasion = contact.occasions.build(kind:, occurs_on:)
      occasion.recurring = recurring unless recurring.nil?
      # Only provided arguments reach `rest`, so an explicit null (reminders off)
      # is distinguishable from an omitted argument (keep the default).
      occasion.reminder_lead_days = rest[:reminder_lead_days] if rest.key?(:reminder_lead_days)

      if occasion.save
        { occasion:, errors: [] }
      else
        { occasion: nil, errors: occasion.errors.full_messages }
      end
    end
  end
end
