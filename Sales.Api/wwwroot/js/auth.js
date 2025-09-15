// /wwwroot/js/auth.js

// ====== CONFIG ======
const AUTH_BASE_URL = "https://localhost:7004"; // Sales.Api port
const LOGIN_ENDPOINT = "/api/Auth/Login";
const REDIRECT_AFTER_LOGIN = "/POS";

// ====== DOM ======
const $form = document.getElementById("loginForm");
const $btn = document.getElementById("loginBtn");
const $alert = document.getElementById("formAlert");
const $toggle = document.getElementById("togglePassword");
const $password = document.getElementById("password");
const $username = document.getElementById("username");
const $remember = document.getElementById("rememberMe");

// ====== UX helpers ======
function showAlert(msg, type = "info") {
  $alert.textContent = msg;
  $alert.classList.remove("hidden", "danger");
  if (type === "danger") $alert.classList.add("danger");
}
function hideAlert() { $alert.classList.add("hidden"); $alert.textContent = ""; }
function setFieldError(name, message) {
  const span = document.querySelector(`[data-error-for="${name}"]`);
  if (span) span.textContent = message || "";
}
function clearErrors() { ["username","password"].forEach(n => setFieldError(n, "")); }

// ====== Password show/hide ======
if ($toggle && $password) {
  $toggle.addEventListener("click", () => {
    const isPwd = $password.type === "password";
    $password.type = isPwd ? "text" : "password";
    $toggle.setAttribute("aria-label", isPwd ? "Hide password" : "Show password");
  });
}

// ====== Persist username if remembered ======
(function hydrateUsername() {
  try {
    const remembered = localStorage.getItem("remembered_username");
    if (remembered && !$username.value) $username.value = remembered;
  } catch {}
})();

// ====== Auth guard helper ======
window.AuthGuard = {
  isAuthenticated() { try { return !!localStorage.getItem("access_token"); } catch { return false; } },
  requireAuth() {
    if (!this.isAuthenticated()) {
      const back = encodeURIComponent(location.pathname + location.search);
      location.href = `/Account/Login?returnUrl=${back}`;
    }
  },
  logout() {
    try {
      localStorage.removeItem("access_token");
      localStorage.removeItem("token_type");
      localStorage.removeItem("expires_at");
    } catch {}
    location.href = "/Account/Login";
  }
};

// ====== Form submit ======
if ($form) {
  $form.addEventListener("submit", async (e) => {
    e.preventDefault();
    hideAlert();
    clearErrors();

    const username = $username.value.trim();
    const password = $password.value;

    let valid = true;
    if (!username) { setFieldError("username", "Username is required."); valid = false; }
    if (!password) { setFieldError("password", "Password is required."); valid = false; }
    if (!valid) return;

    try { // remember me (username only)
      if ($remember.checked) localStorage.setItem("remembered_username", username);
      else localStorage.removeItem("remembered_username");
    } catch {}

    $btn.disabled = true;
    $btn.textContent = "Signing in...";

    try {
      const res = await fetch(`${AUTH_BASE_URL}${LOGIN_ENDPOINT}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password })
      });

      if (!res.ok) {
        let msg = "Login failed.";
        try { const err = await res.json(); msg = err?.message || err?.error || msg; } catch {}
        showAlert(msg, "danger");
        return;
      }

      const data = await res.json();
      const token = data.token || data.accessToken || data.jwt || null;
      if (!token) { showAlert("Server did not return an access token.", "danger"); return; }

      try {
        localStorage.setItem("access_token", token);
        localStorage.setItem("token_type", data.tokenType || "Bearer");
        if (data.expiresIn) {
          const expiresAt = Date.now() + (Number(data.expiresIn) * 1000);
          localStorage.setItem("expires_at", String(expiresAt));
        }
      } catch {}

      const usp = new URLSearchParams(window.location.search);
      const returnUrl = usp.get("returnUrl");
      window.location.href = returnUrl || REDIRECT_AFTER_LOGIN;

    } catch {
      showAlert("Network error. Please check the API URL and try again.", "danger");
    } finally {
      $btn.disabled = false;
      $btn.textContent = "Sign In";
    }
  });
}
