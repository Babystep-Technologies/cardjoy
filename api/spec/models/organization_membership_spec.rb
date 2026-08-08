require "rails_helper"

RSpec.describe OrganizationMembership, type: :model do
  let(:organization) { create(:organization) }

  describe "validations" do
    it "defaults to the member role" do
      expect(described_class.new.role).to eq(described_class::MEMBER)
    end

    it "rejects a role outside admin | member" do
      membership = build(:organization_membership, organization:, role: "owner")
      expect(membership).not_to be_valid
      expect(membership.errors.full_messages).to include("Role is not included in the list")
    end

    it "rejects a blank role" do
      expect(build(:organization_membership, organization:, role: nil)).not_to be_valid
    end

    it "prevents the same user joining one organization twice" do
      user = create(:user)
      create(:organization_membership, organization:, user:)

      duplicate = build(:organization_membership, organization:, user:)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.full_messages).to include("User is already a member of this organization")
    end

    it "is enforced by a unique index as well as the validation" do
      user = create(:user)
      create(:organization_membership, organization:, user:)

      duplicate = build(:organization_membership, organization:, user:)
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "lets the same user be a member of two organizations" do
      user = create(:user)
      create(:organization_membership, organization:, user:)

      expect(build(:organization_membership, organization: create(:organization), user:)).to be_valid
    end
  end

  describe "the last admin guard" do
    it "refuses to demote the only admin" do
      admin = create(:organization_membership, :admin, organization:)

      expect(admin.update(role: described_class::MEMBER)).to be(false)
      expect(admin.errors.full_messages).to include(described_class::LAST_ADMIN_ERROR)
      expect(admin.reload.role).to eq(described_class::ADMIN)
    end

    it "refuses to destroy the only admin" do
      admin = create(:organization_membership, :admin, organization:)

      expect(admin.destroy).to be(false)
      expect(admin.errors.full_messages).to include(described_class::LAST_ADMIN_ERROR)
      expect(described_class.exists?(admin.id)).to be(true)
    end

    it "allows demoting an admin when another admin remains" do
      admin = create(:organization_membership, :admin, organization:)
      create(:organization_membership, :admin, organization:)

      expect(admin.update(role: described_class::MEMBER)).to be(true)
    end

    it "allows destroying an admin when another admin remains" do
      admin = create(:organization_membership, :admin, organization:)
      create(:organization_membership, :admin, organization:)

      expect { admin.destroy }.to change(described_class, :count).by(-1)
    end

    it "allows destroying a plain member even when there is one admin" do
      create(:organization_membership, :admin, organization:)
      member = create(:organization_membership, organization:)

      expect { member.destroy }.to change(described_class, :count).by(-1)
    end

    it "does not block the cascade when the organization itself is destroyed" do
      create(:organization_membership, :admin, organization:)

      expect { organization.destroy! }.to change(described_class, :count).by(-1)
    end

    it "still guards an archived organization's last admin" do
      admin = create(:organization_membership, :admin, organization:)
      organization.archive!

      # Organization's default scope makes `admin.organization` nil here, so the
      # guard has to read through organization_id rather than the association.
      expect(admin.reload.destroy).to be(false)
      expect(described_class.exists?(admin.id)).to be(true)
    end
  end

  describe "#admin?" do
    it "is true only for the admin role" do
      expect(build(:organization_membership, :admin)).to be_admin
      expect(build(:organization_membership)).not_to be_admin
    end
  end
end
