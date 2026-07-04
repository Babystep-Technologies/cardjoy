# typed: true

module Mutations
  class UpdateCoverStyle < BaseMutation
    argument :id, ID, required: true
    argument :tag_names, [ String ], required: true

    field :style, Types::StyleType, null: true
    field :errors, [ String ], null: false

    def resolve(id:, tag_names:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, "Admin access required" unless admin

      style = Style.find_by(id: id, kind: "cover")
      return { style: nil, errors: [ "Cover style not found" ] } unless style

      tags = tag_names.map do |name|
        Tag.find_or_create_by!(name: name.downcase.strip)
      end

      style.tags = tags

      if style.save
        { style: style, errors: [] }
      else
        { style: nil, errors: style.errors.full_messages }
      end
    end
  end
end
