require "rails_helper"

RSpec.describe Organization, type: :model do
  describe "validations" do
    it "requires a name" do
      organization = build(:organization, name: "")
      expect(organization).not_to be_valid
      expect(organization.errors.full_messages).to include("Name can't be blank")
    end

    it "is valid with a name and creator" do
      expect(build(:organization)).to be_valid
    end
  end

  describe "slug generation" do
    it "derives a url-safe slug from the name" do
      organization = create(:organization, name: "Acme Corp")
      expect(organization.slug).to eq("acme-corp")
    end

    it "disambiguates a name that is already taken" do
      create(:organization, name: "Acme Corp")
      expect(create(:organization, name: "Acme Corp").slug).to eq("acme-corp-2")
    end

    it "does not reuse the slug of an archived organization" do
      create(:organization, name: "Acme Corp").archive!

      # The archived row is hidden by the default scope but still holds the
      # slug in the unique index, so a fresh org must not be handed it.
      expect(create(:organization, name: "Acme Corp").slug).to eq("acme-corp-2")
    end

    it "falls back to a default when the name has no url-safe characters" do
      expect(create(:organization, name: "***").slug).to eq("organization")
    end

    it "keeps its slug when renamed" do
      organization = create(:organization, name: "Acme Corp")
      organization.update!(name: "Acme Incorporated")
      expect(organization.slug).to eq("acme-corp")
    end
  end

  describe "#archive!" do
    it "soft-deletes and drops out of the default scope" do
      organization = create(:organization)
      organization.archive!

      expect(organization.deleted_at).to be_present
      expect(described_class.find_by(id: organization.id)).to be_nil
      expect(described_class.unscoped.find_by(id: organization.id)).to be_present
    end
  end

  describe "#membership_for" do
    let(:organization) { create(:organization) }
    let(:member) { create(:user) }

    it "returns the user's membership" do
      membership = create(:organization_membership, organization:, user: member)
      expect(organization.membership_for(member)).to eq(membership)
    end

    it "returns nil for a non-member" do
      expect(organization.membership_for(create(:user))).to be_nil
    end

    it "returns nil for a nil user" do
      expect(organization.membership_for(nil)).to be_nil
    end
  end

  describe "associations" do
    it "lets a user belong to many organizations" do
      user = create(:user)
      create(:organization_membership, user:, organization: create(:organization))
      create(:organization_membership, user:, organization: create(:organization))

      expect(user.organizations.count).to eq(2)
    end

    it "exposes only admin memberships through admin_memberships" do
      organization = create(:organization)
      admin = create(:organization_membership, :admin, organization:)
      create(:organization_membership, organization:)

      expect(organization.admin_memberships).to contain_exactly(admin)
    end

    it "destroys memberships when the organization is destroyed outright" do
      organization = create(:organization)
      create(:organization_membership, :admin, organization:)

      expect { organization.destroy! }.to change(OrganizationMembership, :count).by(-1)
    end
  end
end
