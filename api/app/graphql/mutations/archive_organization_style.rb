# typed: true

module Mutations
  # Retire one of an organization's own design assets (#124).
  #
  # Style is default-scoped to `deleted_at: nil`, so archiving is all it takes
  # for the asset to drop out of the picker; cards already using it keep their
  # card_styles row.
  #
  # Deliberately cannot touch a global curated style (`organization_id` NULL) —
  # that stays with Mutations::ArchiveCoverStyle and the internal admin.
  class ArchiveOrganizationStyle < BaseMutation
    NOT_FOUND_ERROR = "Style not found"

    argument :id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(id:)
      return failure([ NOT_AUTHENTICATED_ERROR ]) unless context[:current_user]

      # The default scope means an already-archived asset reads as not found,
      # which is the right answer for a second archive.
      style = Style.find_by(id: id)
      return failure([ NOT_FOUND_ERROR ]) unless style

      # A global style has no organization, so no one is an admin of it — the
      # same "Not authorized" a non-member gets, which keeps this mutation from
      # confirming that an id belongs to some other organization.
      return failure([ NOT_AUTHORIZED_ERROR ]) unless org_admin?(style.organization)

      style.archive!
      { success: true, errors: [] }
    end

    private

    def failure(errors)
      { success: false, errors: }
    end
  end
end
