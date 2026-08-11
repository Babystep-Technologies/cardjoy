require "rails_helper"

# The access rule for organization-owned records, exercised against both models
# that include it. Card and Invitation share no other code, so a bug fixed in
# one would otherwise silently survive in the other.
RSpec.describe OrganizationScoped do
  let(:owner) { create(:user) }
  let(:member) { create(:user) }
  let(:admin) { create(:user) }
  let(:stranger) { create(:user) }
  let(:organization) { create(:organization) }

  before do
    create(:organization_membership, organization:, user: owner)
    create(:organization_membership, organization:, user: member)
    create(:organization_membership, :admin, organization:, user: admin)
  end

  # [model, factory, extra attributes] — the concern's behaviour must be
  # identical for every record that includes it.
  [ [ Card, :card ], [ Invitation, :invitation ] ].each do |model, factory|
    context "on #{model}" do
      let(:org_record) { create(factory, user: owner, organization:) }
      let(:personal_record) { create(factory, user: owner, organization: nil) }

      describe "#viewable_by?" do
        it "lets any member of the owning organization view it" do
          expect(org_record.viewable_by?(owner)).to be(true)
          expect(org_record.viewable_by?(member)).to be(true)
          expect(org_record.viewable_by?(admin)).to be(true)
        end

        it "refuses a non-member and an anonymous caller" do
          expect(org_record.viewable_by?(stranger)).to be(false)
          expect(org_record.viewable_by?(nil)).to be(false)
        end

        it "keeps a personal record visible to its owner alone" do
          expect(personal_record.viewable_by?(owner)).to be(true)
          expect(personal_record.viewable_by?(member)).to be(false)
          expect(personal_record.viewable_by?(admin)).to be(false)
        end
      end

      describe "#editable_by?" do
        it "lets the owner and an org admin edit, but not an ordinary member" do
          expect(org_record.editable_by?(owner)).to be(true)
          expect(org_record.editable_by?(admin)).to be(true)
          expect(org_record.editable_by?(member)).to be(false)
          expect(org_record.editable_by?(stranger)).to be(false)
          expect(org_record.editable_by?(nil)).to be(false)
        end

        it "keeps a personal record editable by its owner alone" do
          expect(personal_record.editable_by?(owner)).to be(true)
          expect(personal_record.editable_by?(admin)).to be(false)
        end
      end

      # Archiving is a soft delete, so the rows keep their organization_id.
      # Access has to stop anyway: the organization no longer exists as far as
      # the product is concerned, so its records fall back to owner-only.
      it "falls back to owner-only once the organization is archived" do
        record = org_record
        organization.archive!
        record.reload

        expect(record.viewable_by?(member)).to be(false)
        expect(record.editable_by?(admin)).to be(false)
        expect(record.editable_by?(owner)).to be(true)
      end

      describe ".in_context" do
        it "returns the organization's records for an organization context" do
          personal_record

          expect(model.in_context(nil, organization)).to contain_exactly(org_record)
        end

        it "excludes organization records from a personal context" do
          org_record

          expect(model.in_context(owner, nil)).to contain_exactly(personal_record)
        end

        it "scopes a personal context to that user's own records" do
          personal_record
          others = create(factory, user: stranger, organization: nil)

          expect(model.in_context(owner, nil)).not_to include(others)
        end
      end
    end
  end
end
