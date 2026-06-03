# Customer-email actions — preview and send — shared by documents that can be
# emailed (Invoice, DeliveryNote). The host controller supplies the document via
# #email_preview_document and the mail for each context via three argument-free
# methods it must define: #email_preview_mail (preview, with attachments),
# #email_preview_html_mail (HTML-body preview, attachments skipped), and
# #email_for_sending (the mail actually delivered).
module EmailableDocument
  extend ActiveSupport::Concern
  include EmailPreviewHelper

  included do
    # Permit the inline <style> blocks and embedded data: images that the
    # mailer layout produces. Scoped strictly to the iframe response so the
    # parent app's strict CSP remains intact.
    content_security_policy(only: :preview_email_html) do |policy|
      policy.default_src     :none
      policy.style_src       :unsafe_inline
      policy.img_src         :self, :data
      policy.font_src        :none
      policy.script_src      :none
      policy.connect_src     :none
      policy.frame_ancestors :self
    end

    # The global nonce_directives setting auto-injects nonces into script-src
    # and style-src. With both 'unsafe-inline' and a nonce present, the CSP
    # spec tells browsers to ignore 'unsafe-inline' — which would re-block the
    # mailer's inline <style> tags. Strip the nonce list for this action.
    before_action(only: :preview_email_html) { request.content_security_policy_nonce_directives = [] }
  end

  # JSON metadata for the preview modal (to/from/subject/text/attachments). It
  # never touches the HTML body — the modal loads that separately into a
  # sandboxed iframe via #preview_email_html. A document without a recipient
  # has no mail to render, so report that as a flag and skip building it.
  def preview_email
    return render(json: { emailable: false }) unless email_preview_document.emailable?

    render json: extract_email_preview_data(email_preview_mail).merge(emailable: true)
  end

  # Raw HTML body of the email, served into the preview iframe. Attachments are
  # skipped — only the body is needed here — and html_safe is reached solely on
  # the genuine-body branch; the empty fallback renders as plain text.
  def preview_email_html
    body = extract_html_body(email_preview_html_mail)
    if body.present?
      render html: body.html_safe, layout: false
    else
      render plain: "No HTML body — check the plaintext version.", layout: false
    end
  end

  # Queues the customer email for actual delivery. Keeps attachments (the
  # default skip_attachments: false) since this sends for real.
  def send_email
    document = email_preview_document
    unless document.emailable?
      respond_to do |format|
        format.html { redirect_to document, alert: "No recipient configured." }
        format.json { render json: { error: "No recipient configured." }, status: :unprocessable_content }
      end
      return
    end
    email_for_sending.deliver_later
    respond_to do |format|
      format.html { redirect_to document, notice: "E-Mail queued for sending." }
      format.json { head :ok }
    end
  end

  # Shared scaffolding for the bulk "email the selected published documents"
  # action: parse the checkbox ids, guard an empty selection, load the
  # visible-and-published scope, and build the queued/skipped notice. The block
  # receives that scope and returns [queued, skipped]; how each document type
  # groups recipients and delivers differs, so that stays in the host.
  def bulk_send_document_emails(model, ids_param:, redirect_path:, noun:)
    ids = (params[ids_param] || []).reject(&:blank?)
    if ids.empty?
      redirect_to redirect_path, alert: "No #{noun} selected."
      return
    end

    scope = model.visible_to(current_user).where(id: ids, published: true)
    queued, skipped = yield(scope)

    notice = "#{queued} emails queued for sending."
    notice += " #{skipped} skipped (no recipients)." if skipped > 0
    redirect_to redirect_path, notice: notice
  end
end
