#!/usr/bin/env bash
# Fingerprint a project's fastlane setup so the signing / deploy skills route correctly instead of guessing.
# Reports: lanes (+ per-lane scheme / export method / destination), match config & bundle ids, teams, secrets.
# Shared by the signing-provisioning, deploy-staging, and deploy-production skills.
#
# Usage: detect-fastlane.sh [path/to/project-root]   (defaults to CWD; looks for ./fastlane)
set -euo pipefail

ROOT="${1:-.}"
FL="$ROOT/fastlane"
[ -d "$FL" ] || { echo "ERROR: no fastlane/ dir under '$ROOT' (pass the project root as \$1)"; exit 1; }
FF="$FL/Fastfile"; MF="$FL/Matchfile"; AF="$FL/Appfile"

echo "fastlane dir: $FL"
echo

# ---- Appfile: identity & teams ----
if [ -f "$AF" ]; then
  echo "## App identity (Appfile)"
  grep -hE 'app_identifier|apple_id|team_id|itc_team_id' "$AF" | sed 's/#.*//; s/^/  /; /^[[:space:]]*$/d'
  echo
fi

# ---- Matchfile: signing storage ----
if [ -f "$MF" ]; then
  echo "## match config (Matchfile)"
  grep -hE 'git_url|storage_mode|clone_branch_directly|force_for_new_devices|type\(' "$MF" | sed 's/#.*//; s/^/  /; /^[[:space:]]*$/d'
  echo
fi

[ -f "$FF" ] || { echo "(no Fastfile — done)"; exit 0; }

# ---- Lanes ----
echo "## Lanes"
grep -hoE '(private_)?lane :[A-Za-z0-9_]+' "$FF" | sed 's/.*lane :/  /' | sort -u
echo

# ---- match() bundle ids & types (across whole Fastfile) ----
echo "## match() types present:    $(grep -hoE 'type: *"(appstore|adhoc|development|enterprise)"' "$FF" | grep -oE '(appstore|adhoc|development|enterprise)' | sort -u | tr '\n' ' ')"
echo "## force_legacy_encryption:  $(grep -qE 'force_legacy_encryption: *true' "$FF" && echo yes || echo no)"
echo "## bundle ids referenced:    $(grep -hoE '"com\.[A-Za-z0-9._-]+"' "$FF" | tr -d '"' | sort -u | tr '\n' ' ')"
echo

# ---- Per-lane summary (scheme / export method / destination) ----
echo "## Per-lane build & deploy summary"
awk '
  /^  (private_)?lane :/ {
    if (name != "") flush()
    match($0, /lane :[A-Za-z0-9_]+/); name=substr($0,RSTART+6,RLENGTH-6)
    scheme=""; method=""; out=""; dest=""
  }
  name!="" {
    if ($0 ~ /scheme:/)      { s=$0; sub(/.*scheme: *"?/,"",s); sub(/"?,?[[:space:]]*$/,"",s); scheme=s }
    if ($0 ~ /method:/)      { m=$0; sub(/.*method: *"?/,"",m); sub(/"?,?[[:space:]]*$/,"",m); method=m }
    if ($0 ~ /output_name:/) { o=$0; sub(/.*output_name: *"?/,"",o); sub(/"?,?[[:space:]]*$/,"",o); out=o }
    if ($0 ~ /firebase_app_distribution\(/) dest=dest " Firebase"
    if ($0 ~ /pilot\(/)                     dest=dest " TestFlight"
    if ($0 ~ /deliver\(/)                   dest=dest " App-Store-metadata"
  }
  /^  end$/ && name!="" { flush() }
  function flush() {
    if (scheme!="" || dest!="" || method!="") {
      printf "  %-20s scheme=%-16s method=%-9s dest=%s\n", name, (scheme==""?"-":scheme), (method==""?"-":method), (dest==""?"-":dest)
    }
    name=""
  }
  END { if (name!="") flush() }
' "$FF"
echo

# ---- Build-number & secrets ----
echo "## Build number source: $(grep -qE 'snaplaunch|buildnumber' "$FF" && echo 'SnapLaunchOps API (track=ios)' || echo 'local/increment')"
echo "## Committed secrets check:"
for f in "$FL"/.env "$FL"/AuthKey_*.p8 "$FL"/*service*.json "$FL"/*firebase*.json; do
  [ -e "$f" ] || continue
  tracked=$(git -C "$ROOT" ls-files --error-unmatch "$f" 2>/dev/null && echo TRACKED || echo untracked)
  echo "  $(basename "$f"): $tracked"
done
echo
echo "## Routing hints"
echo "  - production deploy → lane exporting method=app-store with dest=TestFlight"
echo "  - staging deploy    → lane with dest=Firebase (ad-hoc), else the app-store lane if no Firebase yet"
echo "  - signing           → drive 'sync_certs' (match); keep force_legacy_encryption if reported yes"
