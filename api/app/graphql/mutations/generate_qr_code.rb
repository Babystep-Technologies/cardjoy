# typed: ignore

require "rqrcode"

module Mutations
  class GenerateQrCode < BaseMutation
    argument :card_external_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false
    field :qr_code_url, String, null: true

    def resolve(card_external_id:)
      user = context[:current_user]
      card = Card.find_by(external_id: card_external_id)
      return { success: false, errors: [ "Card not found" ] } unless card
      return { success: false, errors: [ "Unauthorized" ] } unless card.user_id == user.id

      qr_url = "#{Rails.application.credentials.dig(:frontend_url)}/card/#{card.external_id}/editable"
      qr = RQRCode::QRCode.new(qr_url)
      png = qr.as_png(size: 300)

      card.qr_code.attach(
        io: StringIO.new(png.to_s),
        filename: "card-#{card.external_id}-qr.png",
        content_type: "image/png"
      )
      card.save!
      # Let graphql field resolver handle CDN logic
      { success: true, errors: [], qr_code_url: card.reload.qr_code_url }
    end
  end
end
