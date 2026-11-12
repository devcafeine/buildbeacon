# syntax=docker/dockerfile:1
# BuildBeacon Hub — image Docker : le Hub (Dart compilé) et son interface web (Flutter Web).
# Version du fichier : 1.0 (2026-11-12)
#
#   docker compose up -d --build                     (à la racine du dépôt)
#   docker build -t buildbeacon-hub hub
#   docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 hub
#
# Tout se compile sur la machine de construction ($BUILDPLATFORM), sans
# émulation : l'interface web est la même pour toutes les architectures, et le
# Hub est compilé de façon croisée pour l'architecture visée. Machine de
# construction : Linux x86-64 ou arm64 (Flutter ne tourne pas sur ARMv7).
#
# Image finale : à partir de rien (scratch), le Hub, l'interface, les
# bibliothèques système et certificats de l'image Dart ; utilisateur non root.

ARG DART_VERSION=3.13.5
ARG FLUTTER_VERSION=3.47.6

# ---------------------------------------------------------------------------
# Interface web (Flutter Web)
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
# flutter pub get génère aussi les traductions (fichiers ARB).
RUN flutter pub get
WORKDIR /src/ui
RUN flutter build web --release --no-web-resources-cdn --no-wasm-dry-run \
 # Fichiers inutiles au rendu CanvasKit (Wasm/skwasm, symboles de débogage).
 && cd build/web \
 && rm -rf canvaskit/skwasm* canvaskit/wimp* canvaskit/webparagraph \
 && find . -name '*.symbols' -delete

# ---------------------------------------------------------------------------
# Hub (Dart, compilé pour l'architecture visée)
FROM --platform=$BUILDPLATFORM dart:${DART_VERSION} AS hub
ARG TARGETARCH
ARG BUILDARCH
WORKDIR /src
COPY . .
# L'interface Flutter ne fait pas partie du Hub, et l'image Dart n'a pas
# Flutter : elle sort de l'espace de travail pour cette étape.
RUN sed -i '/^  - ui$/d' pubspec.yaml && rm -rf ui && dart pub get
RUN set -eu; \
    # Dossier des données, à l'utilisateur du Hub (volume initialisé avec).
    mkdir -p /out/data; \
    case "$TARGETARCH" in \
      amd64) arch=x64 ;; \
      arm64) arch=arm64 ;; \
      arm) arch=arm ;; \
      *) echo "Architecture non prise en charge : $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    if [ "$TARGETARCH" = "$BUILDARCH" ]; then \
      dart compile exe server/bin/hub.dart -o /out/hub; \
    else \
      dart compile exe --target-os=linux --target-arch="$arch" \
        server/bin/hub.dart -o /out/hub; \
    fi

# Bibliothèques système et certificats pour l'architecture visée (aucune
# commande n'y est lancée : pas d'émulation).
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
# Chemins fixés ici : un .env de développement (BB_CONFIG, BB_WEB_DIR) ne
# doit pas les changer dans le conteneur.
ENTRYPOINT ["/app/hub", "--config", "/data/config.json", "--web", "/app/web"]
