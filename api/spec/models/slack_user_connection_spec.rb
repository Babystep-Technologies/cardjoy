require 'rails_helper'

RSpec.describe SlackUserConnection, type: :model do
  it "is valid with all required attributes" do
    expect(build(:slack_user_connection)).to be_valid
  end

  it "is invalid without a user" do
    expect(build(:slack_user_connection, user: nil)).not_to be_valid
  end

  it "is invalid without slack_user_id" do
    expect(build(:slack_user_connection, slack_user_id: nil)).not_to be_valid
  end

  it "is invalid without slack_team_id" do
    expect(build(:slack_user_connection, slack_team_id: nil)).not_to be_valid
  end

  it "enforces uniqueness of slack_user_id scoped to slack_team_id" do
    create(:slack_user_connection, slack_user_id: "U123", slack_team_id: "T456")
    expect(build(:slack_user_connection, slack_user_id: "U123", slack_team_id: "T456")).not_to be_valid
  end

  it "allows same slack_user_id in different teams" do
    create(:slack_user_connection, slack_user_id: "U123", slack_team_id: "T001")
    expect(build(:slack_user_connection, slack_user_id: "U123", slack_team_id: "T002")).to be_valid
  end
end
