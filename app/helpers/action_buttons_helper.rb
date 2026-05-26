module ActionButtonsHelper
  # Per-verb helpers for the show-page breadcrumb action cluster. Each helper
  # bakes in the established glyph, Bootstrap color, accessible name (for
  # glyph-only Tier 3), and the link_to-vs-button_to choice. See CLAUDE.md's
  # "Button Glyphs" section for the policy and full mapping.
  #
  # Every helper supports `permission:` and returns nil when denied, so views
  # can pass `actions: [pdf_button(...), delete_button(...)]` and let the
  # breadcrumbs helper compact out the nils.

  # --- Tier 3: glyph-only (title required) ---

  def delete_button(resource, confirm: nil, permission: nil)
    return nil if permission && !can?(permission)
    confirm ||= "Are you sure you want to delete this #{resource.class.name.downcase}?"
    link_to "🗑", resource,
            class: "btn btn-danger",
            title: "Delete",
            "aria-label": "Delete",
            data: { "turbo-method": "delete", "turbo-confirm": confirm }
  end

  def pdf_button(path, permission: nil)
    return nil if permission && !can?(permission)
    link_to "📄", path,
            class: "btn btn-success",
            title: "PDF",
            "aria-label": "PDF",
            target: "_blank",
            data: { turbo: false }
  end

  def preview_button(path, permission: nil)
    return nil if permission && !can?(permission)
    link_to "👁", path,
            class: "btn btn-info",
            title: "Preview",
            "aria-label": "Preview",
            target: "_blank",
            data: { turbo: false }
  end

  # --- Tier 2: glyph + text ---

  def publish_button(path, permission: nil, confirm: nil)
    return nil if permission && !can?(permission)
    button_to "🚀 Publish", path,
              method: :post,
              class: "btn btn-warning",
              data: { "turbo-confirm": confirm }.compact
  end

  def unpublish_button(path, permission: nil, confirm: nil)
    return nil if permission && !can?(permission)
    button_to "↩️ Unpublish", path,
              method: :post,
              class: "btn btn-outline-secondary",
              data: { "turbo-confirm": confirm }.compact
  end

  def convert_to_invoice_button(path, permission: nil, confirm: nil)
    return nil if permission && !can?(permission)
    button_to "🚀 Convert to Invoice", path,
              method: :post,
              class: "btn btn-info",
              data: { "turbo-confirm": confirm }.compact
  end

  def unblock_button(path, permission: nil, confirm: nil)
    return nil if permission && !can?(permission)
    button_to "✅ Unblock", path,
              method: :post,
              class: "btn btn-success",
              data: { "turbo-confirm": confirm }.compact
  end

  def reset_passkeys_button(path, permission: nil, confirm: nil)
    return nil if permission && !can?(permission)
    button_to "Reset passkeys", path,
              method: :post,
              class: "btn btn-warning",
              data: { "turbo-confirm": confirm }.compact
  end

  def audit_log_button(path, permission: nil)
    return nil if permission && !can?(permission)
    link_to "📋 Audit log", path, class: "btn btn-secondary"
  end

  # Cross-resource navigation in the breadcrumb action cluster: jumping to a
  # related list/page (e.g. from a customer to its Invoices, or from Sales Tax
  # rates to Customer/Product Classes). Bakes in `:info` so the convention is
  # not re-decided per caller.
  def nav_button(text, path, permission: nil, data: nil)
    return nil if permission && !can?(permission)
    link_to text, path, class: "btn btn-info", data: data
  end
end
