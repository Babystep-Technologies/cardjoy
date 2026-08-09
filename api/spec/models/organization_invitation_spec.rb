require "rails_helper"

RSpec.describe OrganizationInvitation, type: :model do
  let(:organization) { create(:organization) }

  describe "defaults assigned on create" do
    subject(:invitation) { create(:organization_invitation, organization:) }

    it "defaults to a pending member invitation" do
      expect(invitation.status).to eq(described_class::PENDING)
      expect(invitation.role).to eq(OrganizationMembership::MEMBER)
      expect(invitation.accepted_at).to be_nil
    end

    it "generates a random token" do
      expect(invitation.token).to be_present
      expect(invitation.token).not_to eq(create(:organization_invitation, organization:).token)
    end

    it "expires 14 days out" do
      expect(invitation.expires_at).to be_within(1.minute).of(described_class::EXPIRES_IN.from_now)
    end

    it "keeps a token that was supplied explicitly" do
      expect(create(:organization_invitation, organization:, token: "chosen").token).to eq("chosen")
    end
  end

  describe "validations" do
    it "downcases and strips the email" do
      invitation = create(:organization_invitation, organization:, email: "  Person@Example.COM ")
      expect(invitation.email).to eq("person@example.com")
    end

    it "requires an email" do
      expect(build(:organization_invitation, organization:, email: " ")).not_to be_valid
    end

    it "rejects a malformed email" do
      invitation = build(:organization_invitation, organization:, email: "not-an-email")
      expect(invitation).not_to be_valid
      expect(invitation.errors.full_messages).to include("Email is invalid")
    end

    it "rejects a role outside admin | member" do
      expect(build(:organization_invitation, organization:, role: "owner")).not_to be_valid
    end

    it "rejects a status outside the known set" do
      expect(build(:organization_invitation, organization:, status: "maybe")).not_to be_valid
    end

    it "allows only one pending invitation per email per organization" do
      create(:organization_invitation, organization:, email: "dup@example.com")

      duplicate = build(:organization_invitation, organization:, email: "DUP@example.com")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.full_messages)
        .to include("Email already has a pending invitation to this organization")
    end

    it "backs the pending-invitation rule with a partial unique index" do
      create(:organization_invitation, organization:, email: "dup@example.com")

      # `save(validate: false)` skips the before_validation defaults too, so the
      # not-null columns have to be filled in by hand to reach the index.
      duplicate = build(:organization_invitation, organization:, email: "dup@example.com",
                                                  token: "raced", expires_at: 1.day.from_now)
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "lets the same email be re-invited once the earlier invitation is spent" do
      create(:organization_invitation, :revoked, organization:, email: "dup@example.com")

      expect(build(:organization_invitation, organization:, email: "dup@example.com")).to be_valid
    end

    it "lets the same email be invited to two organizations at once" do
      create(:organization_invitation, organization:, email: "dup@example.com")

      expect(build(:organization_invitation, organization: create(:organization), email: "dup@example.com"))
        .to be_valid
    end
  end

  describe "#usable? and #unusable_reason" do
    it "is usable while pending and unexpired" do
      invitation = create(:organization_invitation, organization:)

      expect(invitation).to be_usable
      expect(invitation.unusable_reason).to be_nil
    end

    it "reports an expired invitation" do
      invitation = create(:organization_invitation, :expired, organization:)

      expect(invitation).not_to be_usable
      expect(invitation.unusable_reason).to eq(described_class::EXPIRED_ERROR)
    end

    it "reports a revoked invitation" do
      invitation = create(:organization_invitation, :revoked, organization:)
      expect(invitation.unusable_reason).to eq(described_class::REVOKED_ERROR)
    end

    it "reports an accepted invitation" do
      invitation = create(:organization_invitation, :accepted, organization:)
      expect(invitation.unusable_reason).to eq(described_class::ALREADY_ACCEPTED_ERROR)
    end

    it "keeps saying revoked after a revoked invitation also lapses" do
      invitation = create(:organization_invitation, :revoked, :expired, organization:)
      expect(invitation.unusable_reason).to eq(described_class::REVOKED_ERROR)
    end

    it "is unusable once the organization is archived" do
      invitation = create(:organization_invitation, organization:)
      organization.archive!

      expect(invitation.reload).not_to be_usable
    end
  end

  describe "#addressed_to?" do
    it "matches the invited email regardless of case" do
      invitation = create(:organization_invitation, organization:, email: "person@example.com")

      expect(invitation.addressed_to?(build(:user, email: "Person@Example.com"))).to be(true)
      expect(invitation.addressed_to?(build(:user, email: "someone@example.com"))).to be(false)
    end
  end

  describe "#accept!" do
    let(:user) { create(:user, email: "person@example.com") }

    it "creates the membership with the invited role and closes the invitation out" do
      invitation = create(:organization_invitation, :admin, organization:, email: user.email)

      membership = invitation.accept!(user)

      expect(membership.role).to eq(OrganizationMembership::ADMIN)
      expect(membership.user).to eq(user)
      expect(invitation.reload.status).to eq(described_class::ACCEPTED)
      expect(invitation.accepted_at).to be_present
    end

    it "reuses an existing membership rather than failing on uniqueness" do
      existing = create(:organization_membership, organization:, user:)
      invitation = create(:organization_invitation, organization:, email: user.email)

      expect { expect(invitation.accept!(user)).to eq(existing) }
        .not_to change(OrganizationMembership, :count)
      expect(invitation.reload.status).to eq(described_class::ACCEPTED)
    end

    it "leaves the invitation pending when the membership can't be written" do
      invitation = create(:organization_invitation, organization:, email: user.email)
      allow(invitation.organization.organization_memberships)
        .to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(OrganizationMembership.new))

      expect { invitation.accept!(user) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(invitation.reload.status).to eq(described_class::PENDING)
    end
  end

  describe "#revoke!" do
    it "marks the invitation revoked" do
      invitation = create(:organization_invitation, organization:)

      invitation.revoke!

      expect(invitation.reload.status).to eq(described_class::REVOKED)
    end
  end

  describe "cascades" do
    it "goes away with the organization" do
      create(:organization_invitation, organization:)
      expect { organization.destroy! }.to change(described_class, :count).by(-1)
    end

    it "goes away with the user who sent it" do
      inviter = create(:user)
      create(:organization_invitation, organization:, invited_by: inviter)

      expect { inviter.destroy! }.to change(described_class, :count).by(-1)
    end
  end
end
