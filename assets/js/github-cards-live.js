// Live-refresh GitHub repo card stats (stars/forks) from the GitHub API in the
// visitor's browser. Build-time values rendered into the page serve as the
// fallback when the API is unreachable or rate-limited, so cards never break.
(function () {
  var TTL_MS = 10 * 60 * 1000; // sessionStorage cache lifetime

  function fetchRepo(repo) {
    var cacheKey = "gh-card:" + repo;
    try {
      var cached = sessionStorage.getItem(cacheKey);
      if (cached) {
        var parsed = JSON.parse(cached);
        if (Date.now() - parsed.t < TTL_MS) return Promise.resolve(parsed.d);
      }
    } catch (e) {
      /* sessionStorage unavailable; fetch anyway */
    }

    return fetch("https://api.github.com/repos/" + repo, {
      headers: { Accept: "application/vnd.github+json" },
    })
      .then(function (res) {
        if (!res.ok) return null;
        return res.json().then(function (j) {
          var d = { stars: j.stargazers_count, forks: j.forks_count };
          try {
            sessionStorage.setItem(cacheKey, JSON.stringify({ t: Date.now(), d: d }));
          } catch (e) {
            /* ignore cache write failures */
          }
          return d;
        });
      })
      .catch(function () {
        return null;
      });
  }

  function updateCards() {
    var cards = document.querySelectorAll(".repo-card[data-repo]");
    var requested = {};
    cards.forEach(function (card) {
      var repo = card.getAttribute("data-repo");
      if (!repo || requested[repo]) return;
      requested[repo] = true;
      fetchRepo(repo).then(function (d) {
        if (!d) return;
        document.querySelectorAll('.repo-card[data-repo="' + repo + '"]').forEach(function (c) {
          var stars = c.querySelector("[data-live-stars]");
          var forks = c.querySelector("[data-live-forks]");
          if (stars) stars.textContent = d.stars;
          if (forks) forks.textContent = d.forks;
        });
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", updateCards);
  } else {
    updateCards();
  }
})();
