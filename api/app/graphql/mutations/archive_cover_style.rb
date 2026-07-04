# typed: strict

module Mutations
  class ArchiveCoverStyle < BaseMutation
    extend T::Sig

    argument :id, ID, required: true

    class Response < T::Struct
      const :success, T::Boolean
      const :errors, T::Array[String]
    end

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    sig { params(id: String).returns(Response) }
    def resolve(id:)
      admin = current_admin
      raise GraphQL::ExecutionError, "Admin access required" unless admin

      style = Style.unscoped.find_by(id: id, kind: "cover")
      return Response.new(success: false, errors: [ "Style not found" ]) unless style

      style.archive!
      Response.new(success: true, errors: [])
    rescue => e
      Response.new(success: false, errors: [ e.message ])
    end

    private
    sig { returns(T.nilable(Admin)) }
    def current_admin
      context[:current_admin].is_a?(Admin) ? context[:current_admin] : nil
    end
  end
end
