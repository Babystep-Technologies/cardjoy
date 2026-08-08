require 'rails_helper'

RSpec.describe User, type: :model do
  describe "signup credit grant" do
    it "grants the signup bonus on creation via a single credit row" do
      user = create(:user)

      signup_credits = user.credits.where(reason: "signup_bonus")
      expect(signup_credits.count).to eq(1)
      expect(signup_credits.first.amount).to eq(User::SIGNUP_CREDIT_GRANT)
      expect(user.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT)
    end

    it "grants the bonus regardless of creation path (OAuth)" do
      user = User.from_slack(slack_user_id: "U1", slack_team_id: "T1", email: "alice@example.com", name: "Alice")

      expect(user.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT)
    end

    it "records a valid signup_bonus event" do
      user = create(:user)
      event = user.credits.find_by(reason: "signup_bonus").events.first

      expect(event["event_kind"]).to eq("signup_bonus")
      expect(event["event_happened_at"]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/)
    end

    it "does not double-grant when the callback runs again" do
      user = create(:user)

      expect { user.send(:grant_signup_credits) }.not_to change { user.credits.count }
    end
  end

  describe "#spend_credit!" do
    it "writes a -1 credit row with the given reason and event kind" do
      user = create(:user)

      credit = ActiveRecord::Base.transaction do
        user.spend_credit!(reason: "card_created", event_kind: "card_created")
      end

      expect(credit.amount).to eq(-1)
      expect(credit.reason).to eq("card_created")
      expect(credit.events.first["event_kind"]).to eq("card_created")
      expect(user.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT - 1)
    end

    it "raises InsufficientCreditsError and writes nothing when the balance is zero" do
      user = create(:user, :without_signup_credits)

      expect do
        ActiveRecord::Base.transaction do
          user.spend_credit!(reason: "card_created", event_kind: "card_created")
        end
      end.to raise_error(User::InsufficientCreditsError)
      expect(user.credit_balance).to eq(0)
    end
  end

  # Uses real threads on separate DB connections, so the data must be committed
  # (truncation, not a wrapping transaction) to be visible across them.
  describe "#spend_credit! concurrency", :truncation do
    self.use_transactional_tests = false

    it "serializes concurrent spends so the balance never goes negative" do
      user = create(:user, :without_signup_credits)
      create(:credit, user: user, amount: 1, reason: "purchase")

      # Two threads race to spend the single available credit. The row lock in
      # #spend_credit! must let exactly one win.
      succeeded = Concurrent::AtomicFixnum.new(0)
      failed = Concurrent::AtomicFixnum.new(0)

      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.transaction do
              User.find(user.id).spend_credit!(reason: "card_created", event_kind: "card_created")
            end
            succeeded.increment
          rescue User::InsufficientCreditsError
            failed.increment
          end
        end
      end
      threads.each(&:join)

      expect(succeeded.value).to eq(1)
      expect(failed.value).to eq(1)
      expect(user.reload.credit_balance).to eq(0)
    end
  end

  describe ".from_slack" do
    let(:slack_user_id) { "U12345" }
    let(:slack_team_id) { "T67890" }

    it "creates a new user with Slack profile data" do
      user = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        email: "alice@example.com",
        name: "Alice"
      )

      expect(user).to be_persisted
      expect(user.email).to eq("alice@example.com")
      expect(user.name).to eq("Alice")
      expect(user.provider).to eq("slack")
      expect(user.uid).to eq("#{slack_team_id}:#{slack_user_id}")
      expect(user.email_confirmed).to be true
    end

    it "returns an existing user when the email matches" do
      existing = create(:user, email: "alice@example.com")

      user = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        email: "alice@example.com",
        name: "Alice"
      )

      expect(user).to eq(existing)
      expect(User.count).to eq(1)
    end

    it "returns nil and creates no account when no email is provided" do
      expect {
        @result = User.from_slack(
          slack_user_id: slack_user_id,
          slack_team_id: slack_team_id
        )
      }.not_to change { User.count }

      expect(@result).to be_nil
    end

    it "returns nil when the email is blank" do
      user = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        email: "  ",
        name: "Alice"
      )

      expect(user).to be_nil
    end

    it "uses 'Slack User' as the default name when a name is not provided" do
      user = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        email: "noname@example.com"
      )

      expect(user.name).to eq("Slack User")
    end

    it "does not create duplicate users for the same Slack identity" do
      first = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        email: "alice@example.com",
        name: "Alice"
      )

      second = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        email: "alice@example.com",
        name: "Alice"
      )

      expect(first).to eq(second)
      expect(User.count).to eq(1)
    end
  end

  describe "active organization" do
    let(:user) { create(:user) }
    let(:organization) { create(:organization) }

    it "defaults to nil, meaning Personal" do
      expect(user.active_organization).to be_nil
      expect(user).to be_valid
    end

    it "accepts an organization the user belongs to" do
      create(:organization_membership, organization:, user:)

      expect(user.update(active_organization: organization)).to be(true)
      expect(user.reload.active_organization).to eq(organization)
    end

    it "rejects an organization the user does not belong to" do
      user.active_organization = organization

      expect(user).not_to be_valid
      expect(user.errors.full_messages)
        .to include("Active organization is not an organization you belong to")
    end

    it "rejects an organization another user belongs to" do
      create(:organization_membership, organization:, user: create(:user))
      user.active_organization = organization

      expect(user).not_to be_valid
    end

    it "reads as Personal once the active organization is archived" do
      create(:organization_membership, :admin, organization:, user:)
      user.update!(active_organization: organization)
      organization.archive!

      expect(user.reload.active_organization).to be_nil
    end

    it "stays saveable after its active organization is archived" do
      create(:organization_membership, :admin, organization:, user:)
      user.update!(active_organization: organization)
      organization.archive!

      # The membership row survives archiving, so the validation must read the
      # raw column rather than the default-scoped association.
      expect(user.reload.update(name: "Renamed")).to be(true)
    end
  end
end
