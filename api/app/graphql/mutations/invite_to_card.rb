# typed: true

module Mutations
  class InviteToCard < BaseMutation
    argument :card_id, ID, required: true
    argument :emails, [ String ], required: true
    argument :kind, String, required: true # "collaborate" or "view"

    field :success, Boolean, null: false

    def resolve(card_id:, emails:, kind:)
      card = Card.find_by(external_id: card_id)

      emails.each do |email|
        if kind == "collaborate"
          CardMailer.collaborator_invite(email, card).deliver_later
        elsif kind == "view"
          CardMailer.viewer_invite(email, card).deliver_later
        end
      end

      { success: true }
    end
  end
end
