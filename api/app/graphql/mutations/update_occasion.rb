# typed: true

module Mutations
  class UpdateOccasion < BaseMutation
    argument :occasion_id, ID, required: true
    argument :kind, String, required: false
    argument :occurs_on, GraphQL::Types::ISO8601Date, required: false
    argument :recurring, Boolean, required: false
    # Days before the occasion to send its reminder. Omit to leave it alone;
    # pass null explicitly to turn reminders off.
    argument :reminder_lead_days, Integer, required: false

    field :occasion, Types::OccasionType, null: true
    field :errors, [ String ], null: false

    def resolve(occasion_id:, kind: nil, occurs_on: nil, recurring: nil, **rest)
      user = context[:current_user]
      return { occasion: nil, errors: [ "Not authenticated" ] } unless user

      occasion = user.occasions.find_by(id: occasion_id)
      return { occasion: nil, errors: [ "Occasion not found or not owned by user" ] } unless occasion

      occasion.kind = kind if kind.present?
      occasion.occurs_on = occurs_on if occurs_on.present?
      occasion.recurring = recurring unless recurring.nil?
      # Only provided arguments reach `rest`, so an explicit null (turn reminders
      # off) is distinguishable from an omitted argument (leave as-is).
      occasion.reminder_lead_days = rest[:reminder_lead_days] if rest.key?(:reminder_lead_days)

      if occasion.save
        { occasion:, errors: [] }
      else
        { occasion: nil, errors: occasion.errors.full_messages }
      end
    end
  end
end
