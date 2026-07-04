require 'rails_helper'

RSpec.describe User, type: :model do
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

    it "generates a placeholder email when none is provided" do
      user = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id
      )

      expect(user.email).to eq("slack+#{slack_user_id}+#{slack_team_id}@cardjoy.app".downcase)
    end

    it "uses 'Slack User' as the default name when none is provided" do
      user = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id
      )

      expect(user.name).to eq("Slack User")
    end

    it "does not create duplicate users for the same Slack identity" do
      first = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        name: "Alice"
      )

      second = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        name: "Alice"
      )

      expect(first).to eq(second)
      expect(User.count).to eq(1)
    end
  end
end
