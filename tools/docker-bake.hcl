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
  labels = [for label in target.docker-metadata-action.labels : replace(label, "__tool__", "bcnode")]
  tags = [for tag in target.docker-metadata-action.tags : replace(tag, "__tool__", "bcnode")]
}

target "bcutil" {
  inherits = ["docker-metadata-action"]
  context = "."
  dockerfile = "tools/Dockerfile"
  target = "bcutil"
  platforms = ["linux/amd64", "linux/arm64"]
  labels = [for label in target.docker-metadata-action.labels : replace(label, "__tool__", "bcutil")]
  tags = [for tag in target.docker-metadata-action.tags : replace(tag, "__tool__", "bcutil")]
}
