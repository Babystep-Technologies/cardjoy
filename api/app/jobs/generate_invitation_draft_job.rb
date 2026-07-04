# typed: true
# frozen_string_literal: true

class GenerateInvitationDraftJob < ApplicationJob
  queue_as :default

  # Non-persisting job: generates a draft payload and returns it.
  # If you later want to persist drafts, replace this implementation.
  def perform(user_id:, prompt:, options: {})
    user = User.find_by(id: user_id)
    return unless user

    generator = Ai::InvitationDraftGenerator.new(user: user, prompt: prompt, options: options)
    result = generator.generate

    # Return the generated payload; do not persist.
    result
  end
end
