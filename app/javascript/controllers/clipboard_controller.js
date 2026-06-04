import { Controller } from "@hotwired/stimulus"

// Copies a value to the clipboard and pops a brief "Copied!" animation.
// Usage:
//   <div data-controller="clipboard" data-clipboard-text-value="host:port">
//     <button data-clipboard-target="button" data-action="clipboard#copy">Copy</button>
//   </div>
export default class extends Controller {
  static targets = ["button"]
  static values = { text: String, duration: { type: Number, default: 1000 } }

  copy(event) {
    event.preventDefault()
    const write = navigator.clipboard
      ? navigator.clipboard.writeText(this.textValue)
      : Promise.reject()

    write.then(() => this.flash()).catch(() => this.fallbackCopy())
  }

  fallbackCopy() {
    const area = document.createElement("textarea")
    area.value = this.textValue
    area.style.position = "fixed"
    area.style.opacity = "0"
    document.body.appendChild(area)
    area.select()
    try { document.execCommand("copy"); this.flash() } catch (_) { /* no-op */ }
    document.body.removeChild(area)
  }

  flash() {
    if (this.cooling) return
    this.cooling = true
    setTimeout(() => { this.cooling = false }, this.durationValue)

    this.popToast()

    if (this.hasButtonTarget) {
      const btn = this.buttonTarget
      btn.classList.add("copied")
      setTimeout(() => btn.classList.remove("copied"), this.durationValue)
    }
  }

  popToast() {
    const anchor = this.hasButtonTarget ? this.buttonTarget : this.element
    const rect = anchor.getBoundingClientRect()
    const toast = document.createElement("span")
    toast.className = "clipboard-toast"
    toast.textContent = "Copied!"
    toast.style.left = `${rect.left + rect.width / 2}px`
    toast.style.top = `${rect.top}px`
    document.body.appendChild(toast)
    toast.addEventListener("animationend", () => toast.remove())
  }
}
