# typed: true

module Queries
  class UserByEmail < BaseQuery
    type Types::UserType, null: true
    argument :email, String, required: true

    def resolve(email:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, "Not authorized" unless admin
      ::User.find_by(email: email)
    end
  end
end
