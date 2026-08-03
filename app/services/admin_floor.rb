# The Admin group must keep at least one active (non-blocked) member;
# recovering from zero needs a database console.
#
# Checked as a post-condition under a row lock, because the pre-checks can't
# hold the line: the UI's `user.groups = [...]` is a `has_many :through`
# assignment that drops join rows with `delete_all`, never reaching
# GroupMembership#prevent_removing_last_admin, and two admins racing a
# check-then-act both see someone else remaining. `had_admin` keeps an install
# already at zero from wedging unrelated membership edits.
module AdminFloor
  class Violation < StandardError
    def initialize(msg = "That would leave the Admin group without an active member.")
      super
    end
  end

  def self.protect!
    group = Group.admin
    return yield if group.nil?

    Group.transaction(requires_new: true) do
      group.lock!
      had_admin = active_admin?(group)
      result = yield
      raise Violation if had_admin && !active_admin?(group)
      result
    end
  end

  # Uncached: both reads issue identical SQL on one connection, so the
  # post-condition must not be servable from the request's query cache.
  def self.active_admin?(group)
    Group.uncached { group.users.active.exists? }
  end
  private_class_method :active_admin?
end
