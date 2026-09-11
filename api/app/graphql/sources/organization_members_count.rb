# typed: true

module Sources
  # Batch-load an organization's member count, so the admin organizations list
  # (#180) costs one grouped query for the whole page instead of one COUNT per
  # row. Mirrors Sources::UserById's shape; see AdminOrganizationType#members_count.
  class OrganizationMembersCount < GraphQL::Dataloader::Source
    def fetch(organization_ids)
      counts = OrganizationMembership.where(organization_id: organization_ids)
        .group(:organization_id)
        .count

      organization_ids.map { |id| counts.fetch(id, 0) }
    end
  end
end
