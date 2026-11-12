# syntax=docker/dockerfile:1
# BuildBeacon Hub — Docker image: the Hub (compiled Dart) and its web interface (Flutter Web).
# File version: 1.1 (2026-11-12) — comments in English.
#
#   docker compose up -d --build                     (at the repository root)
#   docker build -t buildbeacon-hub hub
#   docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 hub
#
# Everything is compiled on the build machine ($BUILDPLATFORM), without
# emulation: the web interface is the same for every architecture, and the Hub
# is cross-compiled for the target architecture. Build machine: Linux x86-64 or
# arm64 (Flutter does not run on ARMv7).
#
# Final image: from scratch, with the Hub, the interface, and the system
# libraries and certificates of the Dart image; non-root user.

ARG DART_VERSION=3.13.5
ARG FLUTTER_VERSION=3.47.6

# ---------------------------------------------------------------------------
# Web interface (Flutter Web)
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS ui
ARG FLUTTER_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:$PATH"
RUN flutter config --no-analytics --no-cli-animations >/dev/null \
 && flutter precache --web
WORKDIR /src
COPY . .
# flutter pub get also generates the translations (ARB files).
RUN flutter pub get
WORKDIR /src/ui
RUN flutter build web --release --no-web-resources-cdn --no-wasm-dry-run \
 # Files the CanvasKit renderer does not use (Wasm/skwasm, debug symbols).
 && cd build/web \
 && rm -rf canvaskit/skwasm* canvaskit/wimp* canvaskit/webparagraph \
 && find . -name '*.symbols' -delete

# ---------------------------------------------------------------------------
# Hub (Dart, compiled for the target architecture)
FROM --platform=$BUILDPLATFORM dart:${DART_VERSION} AS hub
ARG TARGETARCH
ARG BUILDARCH
WORKDIR /src
COPY . .
# The Flutter interface is not part of the Hub, and the Dart image has no
# Flutter: it leaves the workspace for this stage.
RUN sed -i '/^  - ui$/d' pubspec.yaml && rm -rf ui && dart pub get
RUN set -eu; \
    # Data folder, owned by the Hub user (the volume is initialized from it).
    mkdir -p /out/data; \
    case "$TARGETARCH" in \
      amd64) arch=x64 ;; \
      arm64) arch=arm64 ;; \
      arm) arch=arm ;; \
      *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    if [ "$TARGETARCH" = "$BUILDARCH" ]; then \
      dart compile exe server/bin/hub.dart -o /out/hub; \
    else \
      dart compile exe --target-os=linux --target-arch="$arch" \
        server/bin/hub.dart -o /out/hub; \
    fi

# System libraries and certificates for the target architecture (no command
# runs in it: no emulation).
FROM dart:${DART_VERSION} AS runtime

# ---------------------------------------------------------------------------
FROM scratch
COPY --from=runtime /runtime/ /
COPY --from=hub /out/hub /app/hub
COPY --from=ui /src/ui/build/web /app/web
COPY --from=hub --chown=65532:65532 /out/data /data
USER 65532:65532
EXPOSE 8080
VOLUME /data
LABEL org.opencontainers.image.title="BuildBeacon Hub" \
      org.opencontainers.image.description="Drives the BuildBeacon LED tiles through WLED, with its web interface." \
      org.opencontainers.image.source="https://github.com/devcafeine/buildbeacon" \
      org.opencontainers.image.licenses="MIT"
# Paths set here: a development .env (BB_CONFIG, BB_WEB_DIR) must not change
# them in the container.
ENTRYPOINT ["/app/hub", "--config", "/data/config.json", "--web", "/app/web"]
