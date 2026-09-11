# typed: true

# One row per calendar year of admin dashboard targets (#183), replacing the
# copy every admin used to keep for themselves in localStorage.
class AnnualGoal < ApplicationRecord
  validates :year, presence: true, uniqueness: true
  validates :dau_target, :cards_and_invitations_target,
    numericality: { only_integer: true, greater_than: 0 }
end
