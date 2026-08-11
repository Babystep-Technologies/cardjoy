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
    # Blank means Personal. Validated below rather than read from the user's
    # active_organization_id: the client owns the context, the server checks it.
    argument :organization_id, ID, required: false

    field :card, Types::CardType, null: true
    field :errors, [ String ], null: false

    def resolve(title:, recipient:, text:, display_name: nil, style_ids: nil, occasion: nil, cover_image_url: nil, cover_image_file: nil, organization_id: nil)
      user = context[:current_user]
      return { card: nil, errors: [ "Not authenticated" ] } unless user

      # Checked before the transaction opens, so a create into an organization
      # the caller doesn't belong to spends no credit.
      organization = writable_organization(organization_id)
      return { card: nil, errors: [ NOT_AUTHORIZED_ERROR ] } if organization == false

      ApplicationRecord.transaction do
        # Debit first so an insufficient balance blocks the create before we do
        # any image work; the whole transaction rolls back if anything is
        # invalid, so a failed create never burns a credit.
        user.spend_credit!(reason: "card_created", event_kind: "card_created")

        card = user.cards.build(title:, recipients: [ recipient ], kind: "one_on_one", organization:)
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
      end
    rescue User::InsufficientCreditsError
      { card: nil, errors: [ INSUFFICIENT_CREDITS_ERROR ] }
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
