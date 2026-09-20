#!/usr/bin/env bash
# Notarize + staple an archive or DMG with Apple's notary service.
#
# Env:
#   ARTIFACT            path to the file (.zip or .dmg) to notarize
#   NOTARY_KEYCHAIN_PROFILE  local notarytool credential profile (instead of login variables)
#   NOTARY_APPLE_ID     Apple ID email
#   NOTARY_PASSWORD     app-specific password
#   APPLE_TEAM_ID       10-char team id
set -euo pipefail

ARTIFACT="${ARTIFACT:?set ARTIFACT to the artifact path (.zip or .dmg)}"

AUTH=()
if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
  AUTH=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
elif [ -z "${NOTARY_APPLE_ID:-}${NOTARY_PASSWORD:-}${APPLE_TEAM_ID:-}" ]; then
  if [ "${RELEASE_CHANNEL:-Development}" = Release ]; then
    echo "notarize: official releases require notarization credentials" >&2
    exit 1
  fi
  echo "notarize: credentials not set; skipped."
  exit 0
elif [ -z "${NOTARY_APPLE_ID:-}" ] || [ -z "${NOTARY_PASSWORD:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ]; then
  echo "notarize: incomplete credentials; refusing to silently skip" >&2
  exit 1
else
  AUTH=(--apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$APPLE_TEAM_ID")
fi

RESULT="$(mktemp)"
trap 'rm -f "$RESULT"' EXIT

echo "notarize: submitting $ARTIFACT …"
xcrun notarytool submit "$ARTIFACT" \
  "${AUTH[@]}" \
  --wait --output-format json > "$RESULT"
python3 -c 'import json,sys; result=json.load(open(sys.argv[1])); sys.exit(0 if result.get("status") == "Accepted" else "notarize: submission was not Accepted")' "$RESULT"

if [[ "$ARTIFACT" == *.dmg ]] || [[ "$ARTIFACT" == *.app ]]; then
  echo "notarize: stapling ticket …"
  xcrun stapler staple "$ARTIFACT"
  xcrun stapler validate "$ARTIFACT"
fi
echo "notarize: done."
