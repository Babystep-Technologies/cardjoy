# typed: true

class SlackInstallation < ApplicationRecord
  validates :team_id, presence: true, uniqueness: true
  validates :team_name, presence: true
  validates :access_token, presence: true
end
