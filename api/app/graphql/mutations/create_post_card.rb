# typed: true
# frozen_string_literal: true

module Mutations
  # Starts a new post card design.
  #
  # Cost: this deliberately does **not** spend a credit. The `User#spend_credit!`
  # call in `create_card.rb` exists because a digital card *is* the product; here
  # the product is the physical piece of card stock, which is paid for at send
  # time out of the postage wallet. Designing and previewing a post card is
  # free, so please don't "fix" this by adding a debit.
  class CreatePostCard < BaseMutation
    argument :size, String, required: true
    argument :template_id, String, required: true
    # Optional: the title is the user's private label for the card ("Shen family
    # 2026") and is never printed, so there is no reason to make someone name a
    # card before they can start designing it.
    argument :title, String, required: false

    field :post_card, Types::PostCardType, null: true
    field :errors, [ String ], null: false

    def resolve(size:, template_id:, title: nil)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      return failure("Invalid size") unless PostCard::VALID_SIZES.include?(size)

      template = PostCardCatalogue.template(template_id)
      return failure("Unknown template") unless template

      # A template's geometry is drawn for one panel size; rendering a 6x9 layout
      # onto a 6x4 card would push slots past the trim line.
      return failure("Template #{template_id} is not available in size #{size}") unless template.size == size

      post_card = user.post_cards.build(
        size:,
        template_id:,
        title:,
        design_config: empty_design_config
      )

      return failure(post_card.errors.full_messages) unless post_card.save

      { post_card:, errors: [] }
    end

    private

    # A valid, empty design document: the version the model understands and both
    # panels present but unfilled. Seeding the empty sub-objects rather than bare
    # `{}` means the editor always has somewhere to write.
    def empty_design_config
      {
        "version" => PostCard::CURRENT_DESIGN_CONFIG_VERSION,
        "front" => empty_panel,
        "back" => empty_panel
      }
    end

    def empty_panel
      { "photos" => {}, "texts" => {}, "stickers" => [] }
    end

    def failure(errors)
      { post_card: nil, errors: Array(errors) }
    end
  end
end
