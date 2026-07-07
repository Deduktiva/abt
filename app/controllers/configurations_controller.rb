class ConfigurationsController < ApplicationController
  # Replaces the old navbar dropdown: a hub page linking to the various
  # config sub-sections. Visibility is an any-of across those sections'
  # own permissions, not a single scope, so it can't use require_permission!.
  PERMS = %w[issuer_company.view products.view sales_tax.view users.view jobs_status.view groups.manage teams.manage].freeze

  allow_without_permission_check only: [ :index ]

  before_action do
    redirect_to root_path, alert: "You don't have permission to access that page." unless PERMS.any? { |p| current_user&.permission?(p) }
  end

  def index
  end
end
