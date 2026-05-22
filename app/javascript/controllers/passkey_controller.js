import { Controller } from "@hotwired/stimulus"

// Stimulus controller for WebAuthn registration and login.
//
// Targets / data attributes set on the element:
//   data-passkey-options-url-value     — endpoint that returns the challenge JSON
//   data-passkey-verify-url-value      — endpoint that consumes the attestation/assertion
//   data-passkey-nickname-input-value  — (registration only) CSS selector for the nickname input
//
// Actions:
//   register: drives navigator.credentials.create
//   login:    drives navigator.credentials.get

export default class extends Controller {
  static values = {
    optionsUrl:      String,
    verifyUrl:       String,
    nicknameInput:   { type: String, default: "" },
    redirectOnError: { type: String, default: "" }
  }
  static targets = ["status"]

  async register(event) {
    event.preventDefault()
    if (!this._supported()) return

    this._setStatus("Requesting passkey registration…")

    try {
      const options = await this._postJson(this.optionsUrlValue, {})
      const publicKey = this._optionsForCreate(options)
      const credential = await navigator.credentials.create({ publicKey })

      const nickname = this._nicknameValue()
      const result = await this._postJson(this.verifyUrlValue, {
        credential: this._credentialForServer(credential),
        nickname
      })
      this._setStatus("Passkey registered.")
      if (result.redirect_to) {
        window.location.href = result.redirect_to
      } else {
        window.location.reload()
      }
    } catch (err) {
      this._handleError(err)
    }
  }

  async login(event) {
    event.preventDefault()
    if (!this._supported()) return

    this._setStatus("Waiting for passkey…")

    try {
      const options = await this._postJson(this.optionsUrlValue, {})
      const publicKey = this._optionsForGet(options)
      const credential = await navigator.credentials.get({ publicKey })

      const result = await this._postJson(this.verifyUrlValue, {
        credential: this._credentialForServer(credential)
      })
      if (result.redirect_to) {
        window.location.href = result.redirect_to
      } else {
        window.location.reload()
      }
    } catch (err) {
      this._handleError(err)
    }
  }

  // --- helpers ---

  _supported() {
    if (window.PublicKeyCredential && navigator.credentials) return true
    this._setStatus("Passkeys are not supported in this browser.")
    return false
  }

  _setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  _handleError(err) {
    console.error(err)
    const message = err && err.message ? err.message : String(err)
    this._setStatus("Failed: " + message)
  }

  _nicknameValue() {
    if (!this.nicknameInputValue) return ""
    const el = document.querySelector(this.nicknameInputValue)
    return el ? el.value : ""
  }

  async _postJson(url, body) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const resp = await fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type":   "application/json",
        "Accept":         "application/json",
        "X-CSRF-Token":   token || "",
        "X-Requested-With": "XMLHttpRequest"
      },
      body: JSON.stringify(body)
    })
    const data = await resp.json().catch(() => ({}))
    if (!resp.ok) {
      throw new Error(data.error || ("HTTP " + resp.status))
    }
    return data
  }

  // Convert the JSON options returned by webauthn-ruby (base64url-encoded
  // strings) into a structure with ArrayBuffer fields that the WebAuthn API
  // expects.
  _optionsForCreate(opts) {
    const out = { ...opts }
    out.challenge      = this._b64urlToBuf(opts.challenge)
    out.user           = { ...opts.user, id: this._b64urlToBuf(opts.user.id) }
    out.excludeCredentials = (opts.excludeCredentials || []).map(c => ({ ...c, id: this._b64urlToBuf(c.id) }))
    return out
  }

  _optionsForGet(opts) {
    const out = { ...opts }
    out.challenge          = this._b64urlToBuf(opts.challenge)
    out.allowCredentials   = (opts.allowCredentials || []).map(c => ({ ...c, id: this._b64urlToBuf(c.id) }))
    return out
  }

  // Serialise a PublicKeyCredential response for the server. The server-side
  // webauthn-ruby gem expects base64url-encoded fields.
  _credentialForServer(credential) {
    const response = credential.response
    const payload = {
      id: credential.id,
      rawId: this._bufToB64url(credential.rawId),
      type: credential.type,
      authenticatorAttachment: credential.authenticatorAttachment,
      response: {
        clientDataJSON: this._bufToB64url(response.clientDataJSON)
      }
    }
    if (response.attestationObject) {
      payload.response.attestationObject = this._bufToB64url(response.attestationObject)
    }
    if (response.authenticatorData) {
      payload.response.authenticatorData = this._bufToB64url(response.authenticatorData)
      payload.response.signature         = this._bufToB64url(response.signature)
      if (response.userHandle) payload.response.userHandle = this._bufToB64url(response.userHandle)
    }
    if (typeof response.getTransports === "function") {
      payload.response.transports = response.getTransports()
    }
    return payload
  }

  _b64urlToBuf(s) {
    if (!s) return new ArrayBuffer(0)
    const pad = "=".repeat((4 - (s.length % 4)) % 4)
    const b64 = (s + pad).replace(/-/g, "+").replace(/_/g, "/")
    const bin = atob(b64)
    const buf = new Uint8Array(bin.length)
    for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
    return buf.buffer
  }

  _bufToB64url(buf) {
    const bytes = new Uint8Array(buf)
    let s = ""
    for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i])
    return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
  }
}
