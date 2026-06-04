#!/usr/bin/env bash
# Detect an iOS project's environment-separation architecture so the right method is used.
# Verdicts:
#   PATTERN_A  multi-config, single app target  (SnapEdit-style: Staging-*/Production-* configs)
#   PATTERN_B  separate app target per env       (SnapLedger-style: SSMoney / SSMoneyStaging)
#   NONE       greenfield — one app target, only Debug/Release, single scheme
#   MIXED      both signals present (≥2 env app targets AND env-prefixed configs) — inspect by hand
#
# Usage: detect-env-pattern.sh [path/to/App.xcodeproj]   (defaults to first *.xcodeproj found)
set -euo pipefail

PROJ="${1:-}"
[ -z "$PROJ" ] && PROJ="$(find . -maxdepth 3 -name '*.xcodeproj' -not -path '*/Pods/*' 2>/dev/null | head -1)"
[ -n "$PROJ" ] && [ -d "$PROJ" ] || { echo "ERROR: no .xcodeproj found; pass one as \$1"; exit 1; }
PBX="$PROJ/project.pbxproj"
[ -f "$PBX" ] || { echo "ERROR: $PBX missing"; exit 1; }

ENV_RE='(stag|staging|prod|production|dev|develop|debug.*stag|release.*prod)'

# --- App targets (productType == application) ---
APP_TARGETS="$(perl -0777 -ne 'while(/isa = PBXNativeTarget;(.*?)\n\t\t\};/sg){$b=$1; if($b=~/productType = "com\.apple\.product-type\.application"/){ if($b=~/\bname = ("?)([^";]+)\1;/){print "$2\n"}}}' "$PBX" | sort -u)"
APP_COUNT="$(printf '%s\n' "$APP_TARGETS" | grep -c . || true)"
ENV_APP_TARGETS="$(printf '%s\n' "$APP_TARGETS" | grep -iE "$ENV_RE" || true)"

# --- Build configurations (distinct names) ---
CONFIGS="$(perl -0777 -ne 'while(/isa = XCBuildConfiguration;(.*?)\n\t\t\};/sg){$b=$1; if($b=~/\bname = ("?)([^";]+)\1;/){print "$2\n"}}' "$PBX" | sort -u)"
ENV_CONFIGS="$(printf '%s\n' "$CONFIGS" | grep -ivE '^(Debug|Release)$' | grep -iE "$ENV_RE" || true)"

# --- Shared schemes ---
SCHEMES="$(ls "$PROJ/xcshareddata/xcschemes/"*.xcscheme 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.xcscheme$//' || true)"

echo "Project:        $PROJ"
echo "App targets:    $(printf '%s' "$APP_TARGETS" | tr '\n' ' ')"
echo "Configs:        $(printf '%s' "$CONFIGS"     | tr '\n' ' ')"
echo "Shared schemes: $(printf '%s' "$SCHEMES"     | tr '\n' ' ')"
echo

has_env_targets=false; [ -n "$ENV_APP_TARGETS" ] && [ "${APP_COUNT:-0}" -ge 2 ] && has_env_targets=true
has_env_configs=false; [ -n "$ENV_CONFIGS" ] && has_env_configs=true

if $has_env_targets && $has_env_configs; then
  VERDICT="MIXED"
elif $has_env_targets; then
  VERDICT="PATTERN_B"
elif $has_env_configs; then
  VERDICT="PATTERN_A"
else
  VERDICT="NONE"
fi

echo "VERDICT: $VERDICT"
case "$VERDICT" in
  PATTERN_A) echo "→ Multi-config single target (SnapEdit). Extend via env-prefixed configs + xcconfig. Use Pattern A procedure." ;;
  PATTERN_B) echo "→ Separate target per env (SnapLedger). Extend by duplicating the app target. Use Pattern B procedure." ;;
  NONE)      echo "→ Greenfield: no env separation yet. Ask the user which pattern (A if envs differ by settings, B if by files/capabilities)." ;;
  MIXED)     echo "→ Both signals present. Inspect manually before changing anything; do not add a third style." ;;
esac
