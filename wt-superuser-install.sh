#!/usr/bin/env bash
# wt-superuser-install.sh — ONE-SHOT superuser machine install.
#
# Tier 1 (full dev env + superuser identity) and Tier 2 (the seat's keychain secrets) are both automated (S1216,
# tasks 93a71d25 / af10e2bc): the seat proves itself with its CACP token and the golden bootstrap pulls the secrets its
# manifest names from the vault — no hand-placed secret, no Claude session step. Canon: card a0440173.
#
# Best path: sign in at https://my.wikitata.com/setup and run the command it gives you (it carries the sign-in that
# delivers the seat token). This script is the same install pinned to the superuser plane:
#   bash <(curl -fsSL https://start.wikitata.com/wt-superuser-install.sh) <username>
# (override the source with WT_INSTALL_BASE=...; the old start-wikitata-olive.vercel.app alias is gone — 404)
set -euo pipefail
WT_USERNAME="${1:-${WT_USERNAME:-}}"
if [ -z "$WT_USERNAME" ]; then
  read -r -p "wikiTaTa username for this seat: " WT_USERNAME </dev/tty
fi
[ -z "$WT_USERNAME" ] && { echo "a wikiTaTa username is required"; exit 1; }
BASE="${WT_INSTALL_BASE:-https://start.wikitata.com}"

echo "════════════════════════════════════════════════════════════"
echo "  wikiTaTa SUPERUSER install — $WT_USERNAME"
echo "════════════════════════════════════════════════════════════"
echo "Tier 1: full dev env (Node · Claude Code · Supabase/Vercel CLIs · MCP · repos)"
echo "        + superuser identity on the platform plane (onoujm)."
echo ""

# Tier 1 — the full installer, pinned to the superuser plane.
WT_PLANE=super WT_USERNAME="$WT_USERNAME" bash <(curl -fsSL "$BASE/setup.sh")

echo ""
echo "── Tier 2: full-power keychain check ─────────────────────────"
BOOT="$HOME/.local/bin/wt-superuser-bootstrap"
if [ ! -x "$BOOT" ]; then
  curl -fsSL "$BASE/wt-superuser-bootstrap" -o "$BOOT" 2>/dev/null && chmod +x "$BOOT" || true
fi
[ -x "$BOOT" ] && "$BOOT" || echo "(bootstrap helper unavailable — fetch later from $BASE/wt-superuser-bootstrap)"

cat <<'DONE'

════════════════════════════════════════════════════════════
  DONE — quit + reopen Claude Code once.
  It starts as your superuser; every session start re-checks the golden bundle
  and keeps this seat's keychain in sync with your vault (no manual step).
  If Tier 2 said "no seat token": sign in at https://my.wikitata.com/setup,
  run the command it gives you, then: wt-superuser-bootstrap
════════════════════════════════════════════════════════════
DONE
