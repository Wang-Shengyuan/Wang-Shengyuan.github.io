require "net/http"
require "json"
require "uri"

# Fetches GitHub repository/user metadata at build time and exposes it as
# site.data["github_cards"], so repository cards can be rendered as plain
# themed HTML instead of relying on third-party card image services
# (github-readme-stats.vercel.app), which are frequently rate-limited or down.
#
# Set GITHUB_TOKEN (or JEKYLL_GITHUB_TOKEN) to authenticate API requests.
module GithubRepoCards
  LANGUAGE_COLORS = {
    "Python" => "#3572a5",
    "Jupyter Notebook" => "#da5b0b",
    "JavaScript" => "#f1e05a",
    "TypeScript" => "#3178c6",
    "HTML" => "#e34c26",
    "CSS" => "#563d7c",
    "SCSS" => "#c6538c",
    "Shell" => "#89e051",
    "C" => "#555555",
    "C++" => "#f34b7d",
    "C#" => "#178600",
    "Java" => "#b07219",
    "Go" => "#00add8",
    "Rust" => "#dea584",
    "Ruby" => "#701516",
    "TeX" => "#3d6117",
    "MATLAB" => "#e16737",
    "R" => "#198ce7",
    "Lua" => "#000080",
    "Dockerfile" => "#384d54",
    "Vue" => "#41b883",
    "Jinja" => "#a52a22"
  }.freeze

  class Generator < Jekyll::Generator
    safe true
    priority :high

    API_BASE = "https://api.github.com"
    CACHE_TTL = 1800 # seconds; avoids refetching on every `jekyll serve` rebuild

    @@cache = nil
    @@cache_time = nil

    def generate(site)
      config = site.data["repositories"] || {}
      repos = config["github_repos"] || []
      users = config["github_users"] || []

      site.data["github_cards"] = cached_fetch(repos, users)
    end

    private

    def cached_fetch(repos, users)
      key = { "repos" => repos, "users" => users }
      if @@cache && @@cache_time && (Time.now - @@cache_time < CACHE_TTL) && @@cache["key"] == key
        return @@cache["data"]
      end

      data = { "repos" => {}, "users" => {} }
      repos.each { |full_name| data["repos"][full_name] = simplify_repo(fetch_json("#{API_BASE}/repos/#{full_name}")) }
      users.each { |username| data["users"][username] = simplify_user(fetch_json("#{API_BASE}/users/#{username}")) }

      @@cache = { "key" => key, "data" => data }
      @@cache_time = Time.now
      data
    end

    def simplify_repo(json)
      return nil unless json.is_a?(Hash) && json["full_name"]

      {
        "description" => json["description"],
        "language" => json["language"],
        "language_color" => LANGUAGE_COLORS.fetch(json["language"], "#8b949e"),
        "stars" => json["stargazers_count"] || 0,
        "forks" => json["forks_count"] || 0,
        "archived" => json["archived"] || false
      }
    end

    def simplify_user(json)
      return nil unless json.is_a?(Hash) && json["login"]

      {
        "name" => json["name"] || json["login"],
        "bio" => json["bio"],
        "avatar" => json["avatar_url"],
        "followers" => json["followers"] || 0,
        "public_repos" => json["public_repos"] || 0
      }
    end

    def fetch_json(url)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["User-Agent"] = "jekyll-github-repo-cards"
      token = ENV["GITHUB_TOKEN"] || ENV["JEKYLL_GITHUB_TOKEN"]
      request["Authorization"] = "Bearer #{token}" if token && !token.empty?

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        Jekyll.logger.warn("GitHub cards:", "#{url} returned HTTP #{response.code}; rendering fallback card")
        return nil
      end

      JSON.parse(response.body)
    rescue StandardError => e
      Jekyll.logger.warn("GitHub cards:", "failed to fetch #{url}: #{e.message}; rendering fallback card")
      nil
    end
  end
end
