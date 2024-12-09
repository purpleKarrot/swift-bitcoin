target "docker-metadata-action" {}

target "default" {
  inherits = ["docker-metadata-action"]

  name = "swift-bitcoin-${tgt}"
  dockerfile = "tools/Dockerfile"
  matrix = {
    tgt = ["bcnode", "bcutil"]
  }
  target = tgt
  platforms = ["linux/amd64", "linux/arm64"]
}
