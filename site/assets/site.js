// Website of Elio: theme toggle (remembered) and copy buttons on code blocks.
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const dark = document.documentElement.classList.toggle("dark")
      localStorage.setItem("elio-site-theme", dark ? "dark" : "light")
    })
  })

  const copy = document.documentElement.lang === "fr" ? ["Copier", "Copié"] : ["Copy", "Copied"]
  document.querySelectorAll("figure.code").forEach((figure) => {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "copy-button"
    button.textContent = copy[0]
    button.addEventListener("click", async () => {
      await navigator.clipboard.writeText(figure.querySelector("code").textContent)
      button.textContent = copy[1]
      setTimeout(() => { button.textContent = copy[0] }, 2000)
    })
    figure.appendChild(button)
  })
})
