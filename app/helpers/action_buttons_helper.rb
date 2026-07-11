module ActionButtonsHelper
  # Per-verb helpers for the show-page breadcrumb action cluster. Each helper
  # bakes in the established icon, Bootstrap color, accessible name (for
  # icon-only Tier 3), and the link_to-vs-button_to choice. See
  # docs/code-style.md's "Action button icons" section for the policy and
  # full mapping.
  #
  # Every helper supports `permission:` and returns nil when denied, so views
  # can pass `actions: [pdf_button(...), delete_button(...)]` and let the
  # breadcrumbs helper compact out the nils.
  #
  # Shared shapes live as private helpers below: `post_button` for the
  # button_to POST cluster, `icon_link` for the icon-only link_to cluster,
  # `icon_label` for building an icon + text button label.

  # Shared HTML id for the single page-level form on edit/new pages. The
  # breadcrumb's `save_button` and the form element both reference this
  # constant, so the submit button can live outside the <form> and submit it
  # via the HTML5 `form=` attribute.
  PAGE_FORM_ID = "page-form"

  # --- Tier 3: icon-only (title required) ---

  def delete_button(resource, confirm: nil, permission: nil)
    confirm ||= "Are you sure you want to delete this #{resource.class.name.downcase}?"
    icon_link :trash3, resource, klass: "btn btn-danger", title: "Delete",
              permission: permission,
              data: { "turbo-method": "delete", "turbo-confirm": confirm }
  end

  def pdf_button(path, permission: nil)
    icon_link :"file-earmark-pdf-fill", path, klass: "btn btn-success", title: "PDF",
              permission: permission,
              target: "_blank", data: { turbo: false }
  end

  def preview_button(path, permission: nil)
    icon_link :"eye-fill", path, klass: "btn btn-info", title: "Preview",
              permission: permission,
              target: "_blank", data: { turbo: false }
  end

  # --- Tier 2: icon + text ---

  def publish_button(path, permission: nil, confirm: nil)
    post_button icon_label(:send, "Publish"), path, klass: "btn btn-warning", permission: permission, confirm: confirm
  end

  def unpublish_button(path, permission: nil, confirm: nil)
    post_button icon_label(:"arrow-counterclockwise", "Unpublish"), path, klass: "btn btn-outline-secondary", permission: permission, confirm: confirm
  end

  def unblock_button(path, permission: nil, confirm: nil)
    post_button icon_label(:"shield-check", "Unblock"), path, klass: "btn btn-success", permission: permission, confirm: confirm
  end

  def reset_passkeys_button(path, permission: nil, confirm: nil)
    post_button "Reset passkeys", path, klass: "btn btn-warning", permission: permission, confirm: confirm
  end

  def audit_log_button(path, permission: nil)
    return nil if permission && !can?(permission)
    link_to icon_label(:"journal-check", "Audit log"), path, class: "btn btn-secondary"
  end

  # Primary submit button for edit/new pages. Lives in the breadcrumb action
  # cluster and submits the page's main form via the HTML5 `form=` attribute,
  # so the button can sit outside the <form> element. The breadcrumb's parent
  # crumb is the way back — there is no separate Cancel button.
  def save_button(label: "Save", permission: nil)
    return nil if permission && !can?(permission)
    button_tag label, type: :submit, form: PAGE_FORM_ID, class: "btn btn-primary"
  end

  # Cross-resource navigation in the breadcrumb action cluster: jumping to a
  # related list/page (e.g. from a customer to its Invoices, or from Sales Tax
  # rates to Customer/Product Classes). Uses `btn-outline-secondary` so nav
  # reads as quiet/link-ish and yields visual prominence to the page's primary
  # action (`+ New` / `Edit`, which are filled `btn-primary`).
  def nav_button(text, path, permission: nil, data: nil)
    return nil if permission && !can?(permission)
    link_to text, path, class: "btn btn-outline-secondary", data: data
  end

  # Navbar-only: icon-only on desktop, icon + text once the navbar collapses
  # to its mobile stacked list (where a lone icon would be the only
  # unlabeled row). See docs/code-style.md's "Navigation icons" section.
  def sign_out_button
    # ms-2 ≈ the me-1 + inter-element whitespace gap the Configuration and
    # account rows get from their HAML markup; ms-1 alone reads too tight.
    label = nav_icon(:box_arrow_right) + content_tag(:span, "Sign out", class: "d-inline d-sm-none ms-2")
    button_to label, session_path, method: :delete, class: "nav-link nav-icon-btn", title: "Sign out", form_class: "d-flex"
  end

  private

  # Tier-2 shape: POST form button with a Bootstrap class and an optional
  # turbo-confirm prompt. Returns nil when `permission:` is set and the
  # current user lacks it.
  def post_button(label, path, klass:, permission: nil, confirm: nil)
    return nil if permission && !can?(permission)
    button_to label, path,
              method: :post,
              class: klass,
              data: { "turbo-confirm": confirm }.compact
  end

  # Tier-3 shape: icon-only link with a Bootstrap class and an accessible
  # name. The `title:` becomes both the hover tooltip and the screen-reader
  # `aria-label` (the icon itself is `aria-hidden`, via action_icon/nav_icon's
  # shared a11y handling). Extra `link_opts` (e.g. `target:`, `data:`) pass
  # through. Returns nil when `permission:` is set and the current user lacks
  # it.
  def icon_link(icon, path, klass:, title:, permission: nil, **link_opts)
    return nil if permission && !can?(permission)
    link_to action_icon(icon), path, link_opts.merge(class: klass, title: title, "aria-label": title)
  end

  # Tier-2 shape: an icon followed by its label text, for buttons that carry
  # both (Publish, Unblock, Audit log, ...). Text is wrapped in a <span> (not
  # a bare text node) so the `.btn svg.bi:not(:last-child)` CSS rule can tell
  # icon+text buttons apart from icon-only ones and only add the icon/text
  # gap where there's text to gap against.
  def icon_label(icon, text)
    action_icon(icon) + content_tag(:span, text)
  end
end
