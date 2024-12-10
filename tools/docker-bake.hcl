group "default" {
  targets = ["bcnode", "bcutil"]
}

target "docker-metadata-action" {}

target "bcnode" {
  inherits = ["docker-metadata-action"]
  context = "."
  dockerfile = "tools/Dockerfile"
  target = "bcnode"
  platforms = ["linux/amd64", "linux/arm64"]
  tags = [for tag in target.docker-metadata-action.tags : replace(tag, "__tool__", "bcnode")]
  labels = merge(target.docker-metadata-action.labels, {"org.opencontainers.image.version"=replace(target.docker-metadata-action.labels["org.opencontainers.image.version"], "__tool__", "bcnode")})
}

target "bcutil" {
  inherits = ["docker-metadata-action"]
  context = "."
  dockerfile = "tools/Dockerfile"
  target = "bcutil"
  platforms = ["linux/amd64", "linux/arm64"]
  tags = [for tag in target.docker-metadata-action.tags : replace(tag, "__tool__", "bcutil")]
  labels = merge(target.docker-metadata-action.labels, {"org.opencontainers.image.version"=replace(target.docker-metadata-action.labels["org.opencontainers.image.version"], "__tool__", "bcutil")})
}
