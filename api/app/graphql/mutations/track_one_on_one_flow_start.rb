# typed: true

module Mutations
  # Records that a signed-in user landed on the 1-on-1 create flow (#30). Fired
  # once from web/src/pages/Card/OneOnOneNew.tsx on mount. The only consumer is
  # Queries::OneOnOneMetrics's "creation completion rate" denominator — this is
  # not a general analytics event, just a purpose-built funnel counter.
  class TrackOneOnOneFlowStart < BaseMutation
    field :success, Boolean, null: false

    def resolve
      user = context[:current_user]
      return { success: false } unless user

      OneOnOneFlowStart.create!(user:)
      { success: true }
    end
  end
end
