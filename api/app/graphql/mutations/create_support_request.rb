# typed: true

module Mutations
  class CreateSupportRequest < BaseMutation
    argument :reason, String, required: true
    argument :message, String, required: true
    argument :user_email, String, required: true

    field :success, Boolean, null: false

    def resolve(reason:, message:, user_email:)
      SupportMailer.send_case_email(reason, message, user_email).deliver_later
      { success: true }
    end
  end
end
