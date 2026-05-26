import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  connect() {
    if (this.hasLinkTarget) {
      this.linkTarget.click()
    }
    // `?published=1` is a one-shot trigger for the post-publish banner; consume it
    // so reloads (e.g. after send-email) don't re-fire the auto-download.
    const url = new URL(window.location.href)
    if (url.searchParams.has("published")) {
      url.searchParams.delete("published")
      history.replaceState(history.state, "", url.toString())
    }
  }
}
