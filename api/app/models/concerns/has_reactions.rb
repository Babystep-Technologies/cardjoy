# typed: false

module HasReactions
  extend ActiveSupport::Concern
  included do
    def reacted_user_ids
      details["reacted_user_ids"] || []
    end

    def toggle_reaction!(user_id)
      updated_ids = reacted_user_ids.include?(user_id) ?
        reacted_user_ids - [ user_id ] :
        reacted_user_ids + [ user_id ]

      update!(details: details.merge("reacted_user_ids" => updated_ids.uniq))
    end
  end
end
