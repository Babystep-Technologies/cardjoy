# typed: true

require "open-uri"

module Mutations
  class UpdateCard < BaseMutation
    argument :card_id, ID, required: true
    argument :title, String, required: false
    argument :recipients, [ String ], required: false
    argument :style_ids, [ ID ], required: false
    argument :cover_image_url, String, required: false
    argument :occasion, String, required: false
    argument :contributor_prompt, String, required: false
    argument :cover_image_file, ApolloUploadServer::Upload, required: false
    argument :max_messages, Integer, required: false
    argument :require_login_to_contribute, Boolean, required: false
    argument :slug, String, required: false

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(card_id:, title: nil, recipients: nil, occasion: nil, contributor_prompt: nil, style_ids: [], cover_image_url: nil, cover_image_file: nil, max_messages: nil, require_login_to_contribute: nil, slug: nil)
      user = context[:current_user]
      return { success: false, errors: [ "Not authenticated" ] } unless user

      card = Card.find_by(external_id: card_id, user: user)
      return { success: false, errors: [ "Card not found or not owned by user" ] } unless card

      card.title = title if title.present?
      card.recipients = recipients if recipients.present?
      card.occasion = occasion if occasion.present?
      card.contributor_prompt = contributor_prompt unless contributor_prompt.nil?
      card.max_messages = max_messages if max_messages.present?
      card.require_login_to_contribute = require_login_to_contribute unless require_login_to_contribute.nil?
      card.slug = slug unless slug.nil?

      if style_ids.present?
        styles = Style.where(id: style_ids)
        card.styles = styles if styles.any?
      end

      # Handle cover image via URL
      if cover_image_url.present?
        file = URI.open(cover_image_url)
        card.cover_image.attach(io: file, filename: File.basename(T.must(URI.parse(cover_image_url).path)))
      end

      # Handle uploaded file
      if cover_image_file.present?
        card.cover_image.attach(io: cover_image_file.to_io, filename: cover_image_file.original_filename)
      end

      if card.save
        { success: true, errors: [] }
      else
        { success: false, errors: card.errors.full_messages }
      end
    end
  end
end
