import { Controller } from "@hotwired/stimulus"

// Drives WebAuthn registration and authentication ceremonies.
// Uses browser-native PublicKeyCredential.parseCreationOptionsFromJSON /
// parseRequestOptionsFromJSON; falls back to manual base64url decoding when
// the browser lacks those static helpers.
export default class extends Controller {
  static targets = ["username", "fullName", "email", "nickname", "error"]
  static values = {
    optionsUrl: String,
    verifyUrl: String,
    csrfToken: String,
    autoAuthenticate: Boolean,
  }

  connect() {
    if (this.autoAuthenticateValue) {
      // Defer so the page paints first; some browsers gate WebAuthn prompts
      // on the page being visible.
      setTimeout(() => this.authenticate(), 50)
    }
  }

  async register(event) {
    if (event) event.preventDefault()
    this.clearError()
    if (!window.PublicKeyCredential) {
      return this.showError("This browser does not support passkeys.")
    }

    const body = this.signupBody()

    let optionsJSON
    try {
      optionsJSON = await this.postJSON(this.optionsUrlValue, body)
    } catch (e) {
      return this.showError(e.message)
    }

    let credential
    try {
      const publicKey = this.parseCreationOptions(optionsJSON)
      credential = await navigator.credentials.create({ publicKey })
    } catch (e) {
      return this.showError(`Passkey registration was cancelled or failed: ${e.message || e}`)
    }

    let result
    try {
      result = await this.postJSON(this.verifyUrlValue, {
        credential: this.credentialToJSON(credential),
      })
    } catch (e) {
      return this.showError(e.message)
    }

    if (result.redirect_url) {
      window.location.href = result.redirect_url
    }
  }

  async authenticate(event) {
    if (event) event.preventDefault()
    this.clearError()
    if (!window.PublicKeyCredential) {
      return this.showError("This browser does not support passkeys.")
    }

    let optionsJSON
    try {
      optionsJSON = await this.postJSON(this.optionsUrlValue, {})
    } catch (e) {
      return this.showError(e.message)
    }

    let credential
    try {
      const publicKey = this.parseRequestOptions(optionsJSON)
      credential = await navigator.credentials.get({ publicKey })
    } catch (e) {
      return this.showError(`Passkey sign-in was cancelled or failed: ${e.message || e}`)
    }

    let result
    try {
      result = await this.postJSON(this.verifyUrlValue, {
        credential: this.credentialToJSON(credential),
      })
    } catch (e) {
      return this.showError(e.message)
    }

    if (result.redirect_url) {
      window.location.href = result.redirect_url
    }
  }

  signupBody() {
    const body = {}
    if (this.hasUsernameTarget) body.username = this.usernameTarget.value.trim()
    if (this.hasFullNameTarget) body.full_name = this.fullNameTarget.value.trim()
    if (this.hasEmailTarget) body.email = this.emailTarget.value.trim()
    if (this.hasNicknameTarget) body.nickname = this.nicknameTarget.value.trim()
    return body
  }

  async postJSON(url, body) {
    const response = await fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfTokenValue,
      },
      body: JSON.stringify(body),
    })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      throw new Error(data.error || `Request failed (${response.status})`)
    }
    return data
  }

  parseCreationOptions(json) {
    if (typeof PublicKeyCredential.parseCreationOptionsFromJSON === "function") {
      return PublicKeyCredential.parseCreationOptionsFromJSON(json)
    }
    return this.fallbackParseCreationOptions(json)
  }

  parseRequestOptions(json) {
    if (typeof PublicKeyCredential.parseRequestOptionsFromJSON === "function") {
      return PublicKeyCredential.parseRequestOptionsFromJSON(json)
    }
    return this.fallbackParseRequestOptions(json)
  }

  fallbackParseCreationOptions(json) {
    const out = { ...json }
    out.challenge = this.b64urlToBytes(json.challenge)
    out.user = { ...json.user, id: this.b64urlToBytes(json.user.id) }
    if (Array.isArray(json.excludeCredentials)) {
      out.excludeCredentials = json.excludeCredentials.map((c) => ({
        ...c,
        id: this.b64urlToBytes(c.id),
      }))
    }
    return out
  }

  fallbackParseRequestOptions(json) {
    const out = { ...json }
    out.challenge = this.b64urlToBytes(json.challenge)
    if (Array.isArray(json.allowCredentials)) {
      out.allowCredentials = json.allowCredentials.map((c) => ({
        ...c,
        id: this.b64urlToBytes(c.id),
      }))
    }
    return out
  }

  credentialToJSON(credential) {
    if (typeof credential.toJSON === "function") {
      return credential.toJSON()
    }
    return this.fallbackCredentialToJSON(credential)
  }

  fallbackCredentialToJSON(credential) {
    const out = {
      id: credential.id,
      type: credential.type,
      rawId: this.bytesToB64url(credential.rawId),
      clientExtensionResults: credential.getClientExtensionResults
        ? credential.getClientExtensionResults()
        : {},
    }
    const r = credential.response
    if (r.attestationObject) {
      out.response = {
        clientDataJSON: this.bytesToB64url(r.clientDataJSON),
        attestationObject: this.bytesToB64url(r.attestationObject),
      }
    } else {
      out.response = {
        clientDataJSON: this.bytesToB64url(r.clientDataJSON),
        authenticatorData: this.bytesToB64url(r.authenticatorData),
        signature: this.bytesToB64url(r.signature),
        userHandle: r.userHandle ? this.bytesToB64url(r.userHandle) : null,
      }
    }
    return out
  }

  b64urlToBytes(value) {
    const padded = value.replace(/-/g, "+").replace(/_/g, "/")
    const padding = "=".repeat((4 - (padded.length % 4)) % 4)
    const binary = atob(padded + padding)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  }

  bytesToB64url(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i])
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("d-none")
  }

  showError(message) {
    if (!this.hasErrorTarget) {
      console.error(message)
      return
    }
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("d-none")
  }
}
