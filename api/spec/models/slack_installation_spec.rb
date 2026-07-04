require 'rails_helper'

RSpec.describe SlackInstallation, type: :model do
  it "is valid with all required attributes" do
    expect(build(:slack_installation)).to be_valid
  end

  it "is invalid without team_id" do
    expect(build(:slack_installation, team_id: nil)).not_to be_valid
  end

  it "is invalid without team_name" do
    expect(build(:slack_installation, team_name: nil)).not_to be_valid
  end

  it "is invalid without access_token" do
    expect(build(:slack_installation, access_token: nil)).not_to be_valid
  end

  it "enforces unique team_id" do
    create(:slack_installation, team_id: "T12345")
    expect(build(:slack_installation, team_id: "T12345")).not_to be_valid
  end
end
