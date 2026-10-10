#!/usr/bin/env bash
# Regenerates web/.well-known/moopro-instance from $MOOPRO_API_URL at build
# time, so the real production API host lives in the deploy environment's
# own config (e.g. Cloudflare Pages' project "Environment variables"
# setting) rather than hardcoded in source control — set MOOPRO_API_URL
# there (e.g. https://api.moopro.sonibla.com for the production branch, a
# different value for a staging/preview environment if wanted) and point
# the Pages build command at this script before `flutter build web`:
#
#   bash tool/write_instance_discovery.sh && flutter build web --release --base-href /
#
# Leaves the checked-in file (today's real production URL, committed as a
# convenience default — see that file for why a real-looking value is
# safer here than a placeholder) untouched when the variable isn't set, so
# a plain `flutter build web` with no special setup still produces
# something that works, matching this repo's other build-time-overridable
# defaults (`ApiConfig.baseUrl`'s `--dart-define=API_BASE_URL`,
# `Config.APP_URL`'s backend-side default).
set -euo pipefail

if [ -n "${MOOPRO_API_URL:-}" ]; then
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/web/.well-known"
  mkdir -p "$dir"
  cat > "$dir/moopro-instance" <<EOF
{
  "apiUrl": "$MOOPRO_API_URL"
}
EOF
  echo "wrote web/.well-known/moopro-instance with apiUrl=$MOOPRO_API_URL"
else
  echo "MOOPRO_API_URL not set — keeping the checked-in web/.well-known/moopro-instance as-is"
fi
