# Docker image registries (Docker Hub, GHCR, Quay, private ones), read-only:
# Elio asks for the digest of a tag (HEAD of the manifest, not counted by the
# Docker Hub pull limits) to tell whether a newer image is published.
module ImageRegistry
  class Error < StandardError; end

  Reference = Data.define(:registry, :repository, :tag) do
    # Docker's normalization: "nginx:1.27" → docker.io/library/nginx:1.27,
    # "ghcr.io/acme/app:2" → ghcr.io/acme/app:2. nil for a digest-pinned or
    # untagged image (nothing to compare).
    def self.parse(text)
      text = text.to_s.strip
      return if text.empty? || text.include?("@") || text.start_with?("sha256:")

      first, rest = text.split("/", 2)
      registry, path = rest && (first.include?(".") || first.include?(":") || first == "localhost") ? [ first, rest ] : [ "docker.io", text ]
      registry = "docker.io" if registry == "index.docker.io"
      name, _, tag = path.rpartition(":")
      name, tag = path, nil if name.empty? || tag.include?("/")
      name = "library/#{name}" if registry == "docker.io" && !name.include?("/")
      new(registry: registry, repository: name, tag: tag || "latest")
    end

    # Host of the registry API (Docker Hub's is not docker.io).
    def host = registry == "docker.io" ? "registry-1.docker.io" : registry
  end
end
