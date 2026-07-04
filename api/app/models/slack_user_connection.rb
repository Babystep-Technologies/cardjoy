# typed: true

class SlackUserConnection < ApplicationRecord
  belongs_to :user

  validates :slack_user_id, presence: true
  validates :slack_team_id, presence: true
  validates :slack_user_id, uniqueness: { scope: :slack_team_id }
end
