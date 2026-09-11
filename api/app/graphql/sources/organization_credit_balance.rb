# typed: true

module Sources
  # Batch-load an organization's pool balance, so the admin organizations list
  # (#180) costs one grouped query for the whole page instead of one SUM per
  # row. Mirrors Sources::UserById's shape; see AdminOrganizationType#credit_balance.
  class OrganizationCreditBalance < GraphQL::Dataloader::Source
    def fetch(organization_ids)
      balances = OrganizationCredit.where(organization_id: organization_ids)
        .group(:organization_id)
        .sum(:amount)

      organization_ids.map { |id| balances.fetch(id, 0).to_i }
    end
  end
end
