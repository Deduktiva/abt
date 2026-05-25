class TeamsController < ApplicationController
  before_action -> { require_permission!("teams.manage") }
  before_action :load_team, only: [ :show, :edit, :update, :destroy ]

  def index
    @teams = Team.ordered
                 .left_joins(:team_memberships, :customers, :projects)
                 .select('teams.*,
                          COUNT(DISTINCT team_memberships.id) AS member_count,
                          COUNT(DISTINCT customers.id)        AS customer_count,
                          COUNT(DISTINCT projects.id)         AS project_count')
                 .group("teams.id")
  end

  def show
    @members  = @team.users.order(:username)
    @customer_count = @team.customers.count
    @project_count  = @team.projects.count
  end

  def new
    @team = Team.new
  end

  def edit
  end

  def create
    @team = Team.new(team_attributes)
    if @team.save
      assign_members(@team, params.dig(:team, :user_ids))
      audit_privilege_change!("team_created", metadata: { name: @team.name,
                                         member_usernames: @team.users.pluck(:username) })
      redirect_to teams_path, notice: "Team created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    before_members = @team.user_ids.to_set
    if @team.update(team_attributes)
      assign_members(@team, params.dig(:team, :user_ids)) if params.dig(:team, :user_ids)
      after_members = @team.reload.user_ids.to_set
      audit_privilege_change!("team_updated", metadata: {
        name: @team.name,
        members_added: User.where(id: (after_members - before_members).to_a).pluck(:username),
        members_removed: User.where(id: (before_members - after_members).to_a).pluck(:username)
      })
      redirect_to teams_path, notice: "Team updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    name = @team.name
    if @team.destroy
      audit_privilege_change!("team_deleted", metadata: { name: name })
      redirect_to teams_path, notice: "Team deleted."
    else
      redirect_to teams_path, alert: @team.errors.full_messages.join(", ")
    end
  end

  private

  def load_team
    @team = Team.find(params[:id])
  end

  def team_attributes
    params.require(:team).permit(:name, :description)
  end

  def assign_members(team, user_ids)
    new_ids = Array(user_ids).reject(&:blank?).map(&:to_i)
    team.users = User.where(id: new_ids).to_a
  end
end
