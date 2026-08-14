# typed: true

module Sources
  # Batch-load users by id, so a list of rows that each name a person costs one
  # query instead of one per row. The schema already enables GraphQL::Dataloader
  # (see ApiSchema); this is the first source to use it.
  #
  # Returns nil for an id with no user — a ledger row can outlive the account it
  # names, and the field that reads it is nullable for exactly that reason.
  class UserById < GraphQL::Dataloader::Source
    def fetch(ids)
      users = User.where(id: ids).index_by(&:id)
      ids.map { |id| users[id] }
    end
  end
end
