# typed: true

module Sources
  # Batch-load admins by id, mirroring Sources::UserById — a ledger list where
  # every row names the acting admin would otherwise cost one query per row.
  class AdminById < GraphQL::Dataloader::Source
    def fetch(ids)
      admins = Admin.where(id: ids).index_by(&:id)
      ids.map { |id| admins[id] }
    end
  end
end
