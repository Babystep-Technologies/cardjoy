# typed: true

module Queries
  class User < BaseQuery
    type Types::UserType, null: true
    argument :id, ID, required: true

    def resolve(id:)
      ::User.find_by(id: id)
    end
  end
end
