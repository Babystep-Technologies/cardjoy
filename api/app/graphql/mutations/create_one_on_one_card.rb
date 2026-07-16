# typed: true
# frozen_string_literal: true

require "open-uri"

module Mutations
  # Single-flow creation for a 1-on-1 card: builds a `one_on_one` card and the
  # sender's message in one transaction. Requires an authenticated creator; the
  # card is owned by `current_user`, same as `CreateCard`.
  class CreateOneOnOneCard < BaseMutation
    extend T::Sig
    argument :title, String, required: true
    argument :recipient, String, required: true
    argument :text, String, required: true
    argument :display_name, String, required: false
    argument :style_ids, [ ID ], required: false
    argument :occasion, String, required: false
    argument :cover_image_url, String, required: false
    argument :cover_image_file, ApolloUploadServer::Upload, required: false

    field :card, Types::CardType, null: true
    field :errors, [ String ], null: false

    def resolve(title:, recipient:, text:, display_name: nil, style_ids: nil, occasion: nil, cover_image_url: nil, cover_image_file: nil)
      user = context[:current_user]
      return { card: nil, errors: [ "Not authenticated" ] } unless user

      ApplicationRecord.transaction do
        card = user.cards.build(title:, recipients: [ recipient ], kind: "one_on_one")
        styles = Style.where(id: style_ids)
        card.styles << styles if styles.any?
        card.occasion = occasion if occasion

        if cover_image_file.present? && cover_image_file.respond_to?(:to_io)
          card.cover_image.attach(io: cover_image_file.to_io, filename: cover_image_file.original_filename)
        elsif cover_image_url.present?
          downloaded_file = URI.open(cover_image_url)
          uri = URI.parse(cover_image_url)
          filename = File.basename(T.must(uri.path))
          card.cover_image.attach(io: downloaded_file, filename:)
        end

        card.save!

        message = card.messages.build(user:, text:)
        message.display_name = display_name if display_name.present?
        message.save!

        { card:, errors: [] }
      rescue ActiveRecord::RecordInvalid => e
        # Extract and format validation errors for better user experience
        errors = e.record.errors.full_messages.map do |msg|
          # Make cover image size errors more user-friendly
          if msg.include?("Cover image") && msg.include?("less than 10")
            "Cover image file size is too large. Please choose an image smaller than 10MB."
          elsif msg.include?("Cover image") && msg.include?("valid image format")
            "Cover image must be in PNG, JPG, JPEG, or GIF format."
          else
            msg
          end
        end
        { card: nil, errors: }
      rescue OpenURI::HTTPError => e
        { card: nil, errors: [ "Failed to download cover image: #{e.message}" ] }
      end
    end
  end
end
