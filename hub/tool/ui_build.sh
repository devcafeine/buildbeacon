#!/bin/sh
# BuildBeacon — builds the web interface (hub/ui/build/web) only when its sources changed.
# File version: 1.0 (2026-11-12)
#
# Run by `mise run ui-build`, and so before `mise run hub`: the Hub never
# serves an interface older than the code. Sources: the code of the
# interface, its translations (ARB files, not the generated ones), web
# files, assets, and the core and SDK it uses. To force a build: delete
# hub/ui/build.
#
# The stamp is written after each successful build: Flutter does not rewrite
# an output whose content did not change, so its date cannot be used.
set -eu
cd "$(dirname "$0")/../ui"

stamp=build/web/.buildbeacon-built
newer=$(find lib web assets pubspec.yaml l10n.yaml ../core/lib ../sdk/lib \
  -type f ! -name 'app_localizations*.dart' -newer "$stamp" -print 2>/dev/null |
  head -n 1)

if [ -f "$stamp" ] && [ -z "$newer" ]; then
  echo "Web interface up to date (hub/ui/build/web)."
  exit 0
fi
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
touch "$stamp"
