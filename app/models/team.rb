class Team < ApplicationRecord
  # Initial name of the built-in default team. Only used when seeding/
  # creating the team; lookups go through Team.default which uses the
  # dedicated `default` column so the team stays renamable.
  DEFAULT_NAME = "Default".freeze

  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships
  has_many :customers
  has_many :projects

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 60 }
  validates :description, length: { maximum: 200 }

  before_destroy :prevent_destroy_if_builtin
  before_destroy :prevent_destroy_if_used

  scope :ordered, -> { order(:name) }

  # The single team marked `default: true`. Distinct from `builtin?` (which
  # means "system-managed, can't delete"): the default flag identifies the
  # team new users auto-join via User#join_default_team. A partial unique
  # index on `default` enforces at most one default at the DB level.
  def self.default
    find_by(default: true)
  end

  def used?
    customers.exists? || projects.exists?
  end

  private

  def prevent_destroy_if_builtin
    if builtin?
      errors.add(:base, "Cannot delete a built-in team")
      throw :abort
    end
  end

  def prevent_destroy_if_used
    if used?
      errors.add(:base, "Cannot delete a team that owns customers or projects")
      throw :abort
    end
  end
end
