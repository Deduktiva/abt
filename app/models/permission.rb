module Permission
  # admin_only: true means the permission cannot be assigned to any non-Admin
  # group from the UI or via the model. Used for capabilities that carry
  # latent admin-equivalent power (issuing/resetting auth credentials,
  # auto-confirming emails on arbitrary users — see app/controllers/users/
  # emails_controller.rb and UsersController#reset_passkeys).
  Entry = Struct.new(:key, :label, :category, :admin_only, keyword_init: true)

  ALL = [
    # Operations
    Entry.new(key: "customers.view",      label: "View customers",          category: "Operations"),
    Entry.new(key: "customers.edit",      label: "Create / edit customers", category: "Operations"),
    Entry.new(key: "projects.view",       label: "View projects",           category: "Operations"),
    Entry.new(key: "projects.edit",       label: "Create / edit projects",  category: "Operations"),
    Entry.new(key: "invoices.view",       label: "View invoices",           category: "Operations"),
    Entry.new(key: "invoices.edit",       label: "Create / publish / send invoices", category: "Operations"),
    Entry.new(key: "delivery_notes.view", label: "View delivery notes",     category: "Operations"),
    Entry.new(key: "delivery_notes.edit", label: "Create / publish / send delivery notes", category: "Operations"),
    Entry.new(key: "delivery_notes.review_acceptance", label: "Review delivery-note acceptance submissions", category: "Operations"),

    # Catalog & tax
    Entry.new(key: "products.view", label: "View product catalog",          category: "Catalog & tax"),
    Entry.new(key: "products.edit", label: "Create / edit products",        category: "Catalog & tax"),
    Entry.new(key: "sales_tax.view", label: "View sales tax configuration", category: "Catalog & tax"),
    Entry.new(key: "sales_tax.edit", label: "Edit sales tax configuration", category: "Catalog & tax"),

    # Company settings
    Entry.new(key: "issuer_company.view", label: "View issuer company",     category: "Company settings"),
    Entry.new(key: "issuer_company.edit", label: "Edit issuer company",     category: "Company settings"),

    # Administration
    Entry.new(key: "users.view",                label: "View users",                          category: "Administration"),
    Entry.new(key: "users.block",               label: "Block and unblock users",             category: "Administration"),
    Entry.new(key: "users.reset_passkeys",      label: "Reset user passkeys (Admin only)",    category: "Administration", admin_only: true),
    Entry.new(key: "users.auto_confirm_email",  label: "Add / replace / remove user emails without verification (Admin only)", category: "Administration", admin_only: true),
    Entry.new(key: "user_invites.manage",       label: "Create user invites",                 category: "Administration"),
    Entry.new(key: "groups.manage",             label: "Manage groups and permissions",       category: "Administration"),
    Entry.new(key: "teams.manage",              label: "Manage teams and team memberships",   category: "Administration"),
    Entry.new(key: "jobs_status.view",          label: "View background jobs status",         category: "Administration")
  ].freeze

  ALL_KEYS = ALL.map(&:key).to_set.freeze

  ADMIN_ONLY_KEYS = ALL.select(&:admin_only).map(&:key).to_set.freeze

  CATEGORIES = ALL.map(&:category).uniq.freeze

  def self.grouped
    @grouped ||= ALL.group_by(&:category).freeze
  end

  def self.valid?(key)
    ALL_KEYS.include?(key)
  end

  def self.admin_only?(key)
    ADMIN_ONLY_KEYS.include?(key)
  end

  def self.label_for(key)
    ALL.find { |e| e.key == key }&.label || key
  end
end
