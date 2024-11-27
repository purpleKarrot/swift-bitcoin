# syntax=docker/dockerfile:1

FROM swift:6.0.2 AS builder
COPY . /opt/swift-bitcoin
WORKDIR /opt/swift-bitcoin
RUN \
    swift sdk install https://download.swift.org/swift-6.0.2-release/static-sdk/swift-6.0.2-RELEASE/swift-6.0.2-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz --checksum aa5515476a403797223fc2aad4ca0c3bf83995d5427fb297cab1d93c68cee075 && \
    swift build -c release --swift-sdk aarch64-swift-linux-musl
    # && \ swift test

FROM scratch AS bcutil
COPY --from=builder /opt/swift-bitcoin/.build/aarch64-swift-linux-musl/release/bcutil /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/bcutil"]

FROM scratch AS bcnode
COPY --from=builder /opt/swift-bitcoin/.build/aarch64-swift-linux-musl/release/bcnode /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/bcnode"]
