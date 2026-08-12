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

  describe "#credit_balance" do
    let(:organization) { create(:organization) }

    it "is zero for a pool nobody has funded" do
      expect(organization.credit_balance).to eq(0)
    end

    it "sums the ledger, signed" do
      create(:organization_credit, organization:, amount: 10)
      create(:organization_credit, organization:, amount: 5)
      create(:organization_credit, organization:, amount: -3)

      expect(organization.credit_balance).to eq(12)
    end

    it "ignores other organizations' pools and personal ledgers" do
      create(:organization_credit, organization:, amount: 4)
      create(:organization_credit, organization: create(:organization), amount: 100)
      create(:credit, amount: 100)

      expect(organization.credit_balance).to eq(4)
    end
  end

  describe "#allocate_credits!" do
    let(:admin) { create(:user) }
    let(:organization) { create(:organization, created_by: admin) }
    let(:member) { create(:user) }

    before do
      create(:organization_membership, :admin, organization:, user: admin)
      create(:organization_membership, organization:, user: member)
      create(:organization_credit, organization:, amount: 10)
    end

    def allocate(amount, user: member)
      ApplicationRecord.transaction do
        organization.allocate_credits!(user: user, amount: amount, allocated_by: admin)
      end
    end

    it "moves credits out of the pool and into the member's ledger" do
      credit = allocate(4)

      expect(organization.credit_balance).to eq(6)
      expect(member.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT + 4)
      expect(credit.amount).to eq(4)
      expect(credit.user).to eq(member)
    end

    it "writes both halves of the transfer with a matching audit trail" do
      allocate(3)

      pool_row = organization.organization_credits.order(:created_at).last
      personal_row = member.credits.order(:created_at).last

      expect(pool_row.amount).to eq(-3)
      expect(pool_row.reason).to eq("org_allocation")
      expect(personal_row.reason).to eq("org_allocation")
      expect(pool_row.events.first["event_kind"]).to eq("org_credit_allocated")
      expect(personal_row.events.first["event_kind"]).to eq("org_credit_allocated")
      expect(personal_row.events.first["event_data"]).to include(
        "organization_id" => organization.id,
        "user_id" => member.id,
        "allocated_by_user_id" => admin.id,
        "amount" => 3
      )
    end

    it "raises InsufficientPoolCreditsError and writes nothing when the pool is short" do
      expect { allocate(11) }.to raise_error(Organization::InsufficientPoolCreditsError)

      expect(organization.credit_balance).to eq(10)
      expect(member.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT)
    end

    it "raises ArgumentError for a zero or negative amount" do
      expect { allocate(0) }.to raise_error(ArgumentError)
      expect { allocate(-5) }.to raise_error(ArgumentError)

      expect(organization.credit_balance).to eq(10)
    end

    it "raises NotAMemberError for a user who does not belong to the organization" do
      stranger = create(:user)

      expect { allocate(1, user: stranger) }.to raise_error(Organization::NotAMemberError)

      expect(organization.credit_balance).to eq(10)
      expect(stranger.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT)
    end

    it "rolls back the pool debit when the personal credit fails to save" do
      allow(member).to receive(:credits).and_raise(ActiveRecord::RecordInvalid.new(Credit.new))

      expect { allocate(2) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(organization.credit_balance).to eq(10)
    end

    it "leaves the allocated credits spendable through the unchanged User#spend_credit!" do
      spender = create(:user, :without_signup_credits)
      create(:organization_membership, organization:, user: spender)

      allocate(2, user: spender)
      ApplicationRecord.transaction do
        spender.spend_credit!(reason: "card_created", event_kind: "card_created")
      end

      expect(spender.credit_balance).to eq(1)
    end
  end

  # Uses real threads on separate DB connections, so the data must be committed
  # (truncation, not a wrapping transaction) to be visible across them.
  describe "#allocate_credits! concurrency", :truncation do
    self.use_transactional_tests = false

    it "serializes concurrent allocations so the pool never goes negative" do
      admin = create(:user)
      organization = create(:organization, created_by: admin)
      create(:organization_membership, :admin, organization:, user: admin)
      members = 2.times.map do |_i|
        create(:user).tap { |user| create(:organization_membership, organization:, user:) }
      end
      create(:organization_credit, organization:, amount: 1)

      # Two admins race to allocate the single pooled credit. The row lock in
      # #allocate_credits! must let exactly one win.
      succeeded = Concurrent::AtomicFixnum.new(0)
      failed = Concurrent::AtomicFixnum.new(0)

      threads = members.map do |member|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.transaction do
              Organization.find(organization.id)
                          .allocate_credits!(user: member, amount: 1, allocated_by: admin)
            end
            succeeded.increment
          rescue Organization::InsufficientPoolCreditsError
            failed.increment
          end
        end
      end
      threads.each(&:join)

      expect(succeeded.value).to eq(1)
      expect(failed.value).to eq(1)
      expect(organization.reload.credit_balance).to eq(0)
    end
  end

  # These three values are interpolated into outgoing email — two into its CSS,
  # one into a header — so their shape is enforced here rather than trusted
  # (#123).
  describe "brand fields" do
    subject(:organization) { build(:organization) }

    it "accepts three- and six-digit hex accent colors" do
      expect(build(:organization, accent_color: "#433c69")).to be_valid
      expect(build(:organization, accent_color: "#f0a")).to be_valid
    end

    it "rejects an accent color that isn't a bare hex value" do
      [ "red", "433c69", "#4433c69", "#43_c69", "#433c69; background: url(x)" ].each do |value|
        organization = build(:organization, accent_color: value)

        expect(organization).not_to be_valid, "expected #{value.inspect} to be rejected"
        expect(organization.errors[:accent_color]).to include("must be a hex color like #433c69")
      end
    end

    it "rejects a reply-to that isn't an email address" do
      organization = build(:organization, email_reply_to: "not-an-address")

      expect(organization).not_to be_valid
      expect(organization.errors[:email_reply_to]).to be_present
    end

    it "rejects footer text longer than the maximum" do
      organization = build(:organization,
                           email_footer_text: "x" * (Organization::FOOTER_TEXT_MAX_LENGTH + 1))

      expect(organization).not_to be_valid
      expect(organization.errors[:email_footer_text]).to be_present
    end

    it "treats every brand field as optional" do
      expect(build(:organization, accent_color: nil, email_reply_to: nil, email_footer_text: nil))
        .to be_valid
      expect(build(:organization, accent_color: "", email_reply_to: "", email_footer_text: ""))
        .to be_valid
    end

    it "rejects a logo that isn't a supported image" do
      organization.logo.attach(
        io: StringIO.new("not an image"), filename: "logo.txt", content_type: "text/plain"
      )

      expect(organization).not_to be_valid
      expect(organization.errors[:logo]).to include("must be a valid image format")
    end

    it "exposes no logo_url until a logo is attached" do
      organization.save!
      expect(organization.logo_url).to be_nil

      organization.logo.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
        filename: "logo.jpg",
        content_type: "image/jpeg"
      )

      expect(organization.logo_url).to be_present
    end
  end
end
