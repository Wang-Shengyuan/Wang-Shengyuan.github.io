// Rejoins addresses emitted in halves and copies them on click.
// Vanilla JS: harvesters parse markup, so the address must never appear as
// user@host in HTML. See _plugins/email-protect.rb.
(function () {
  "use strict";

  var TOAST_ID = "al-email-copied-toast";
  var TOAST_MS = 1800;
  var toastTimer = null;

  function showToast(message) {
    var toast = document.getElementById(TOAST_ID);
    if (!toast) {
      toast = document.createElement("div");
      toast.id = TOAST_ID;
      toast.setAttribute("role", "status");
      toast.setAttribute("aria-live", "polite");
      document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.classList.add("is-visible");
    if (toastTimer) {
      clearTimeout(toastTimer);
    }
    toastTimer = setTimeout(function () {
      toast.classList.remove("is-visible");
      toastTimer = null;
    }, TOAST_MS);
  }

  function legacyCopy(text) {
    var field = document.createElement("textarea");
    field.value = text;
    field.setAttribute("readonly", "");
    field.style.cssText = "position:fixed;top:0;left:0;opacity:0";
    document.body.appendChild(field);
    field.select();
    var copied = false;
    try {
      copied = document.execCommand("copy");
    } catch (err) {
      copied = false;
    }
    document.body.removeChild(field);
    return copied;
  }

  function copyAddress(address) {
    if (!address) {
      return;
    }
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(address).then(
        function () {
          showToast("Email copied to clipboard");
        },
        function () {
          showToast(address);
        }
      );
      return;
    }
    showToast(legacyCopy(address) ? "Email copied to clipboard" : address);
  }

  window.copyProtectedEmail = function (local, domain) {
    if (!local || !domain) {
      return;
    }
    copyAddress(local + "@" + domain);
  };

  function addressOf(element) {
    var local = element.getAttribute("data-eu");
    var domain = element.getAttribute("data-ed");
    if (!local || !domain) {
      return null;
    }
    return local + "@" + domain;
  }

  function onActivate(event) {
    var element = event.target.closest ? event.target.closest(".al-email-protect") : null;
    if (!element) {
      return;
    }
    event.preventDefault();
    copyAddress(addressOf(element));
  }

  function ready() {
    document.addEventListener("click", onActivate);
    document.addEventListener("keydown", function (event) {
      if (event.key !== " " && event.key !== "Spacebar") {
        return;
      }
      var element = event.target.closest ? event.target.closest(".al-email-protect") : null;
      if (element) {
        event.preventDefault();
        copyAddress(addressOf(element));
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", ready);
  } else {
    ready();
  }
})();
