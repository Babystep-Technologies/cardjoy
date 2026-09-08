# typed: true
# frozen_string_literal: true

module Types
  # Whether the two PostGrid-backed halves of the send flow can run at all
  # (#153).
  #
  # Both mutations already refuse when PostGrid is unconfigured — see
  # GenerateHolidayCardProof and SendHolidayCard, which return
  # `UNAVAILABLE_ERROR` rather than raising. This type exists so a client can ask
  # *before* walking someone through picking forty recipients, instead of
  # discovering it at the charge step.
  #
  # Two booleans rather than one because they read different keys: proofs run in
  # test mode and mailing in live mode (PostGrid::ProofGenerator::MODE and
  # MailSubmission::MODE), so a deploy can genuinely have one without the other.
  # The client needs both to finish a send and says so.
  class HolidayCardMailingAvailabilityType < Types::BaseObject
    description "Whether holiday cards can currently be proofed and mailed."

    field :proofs_available, Boolean, null: false,
      description: "Whether a print proof can be rendered. False disables the proof stage."
    field :mailing_available, Boolean, null: false,
      description: "Whether pieces can be submitted for print and post. False disables sending."
  end
end
