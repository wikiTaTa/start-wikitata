#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# wikiTaTa — Developer Setup
# One script. Checks everything. Installs what's missing. Configures Claude.
# ═══════════════════════════════════════════════════════════════════════════════

set -uo pipefail

# ── Accept username as argument (pre-filled from web page) ───────────────────
# S1216: keep a username the /i/<code> shim EXPORTED. This line used to be "${1:-}", which wiped the shim's
# WT_USERNAME, so every signed-in one-liner fell into the "no username → open the browser" exit below.
WT_USERNAME="${1:-${WT_USERNAME:-}}"

# ── Linux → the ONE Linux installer (S1253, task 81e3f575; One Instance Law) ──
# /i/<code> serves this script to Mac AND Linux. Everything below is macOS (Xcode, Homebrew, keychain, launchd), so
# on Linux this run hands off to onboard-linux.sh, which keeps the username and the WT_JWT / WT_SB_ANON_KEY the
# /i/<code> shim exported.
if [ "$(uname -s)" = "Linux" ]; then
  export WT_USERNAME
  exec bash <(curl -fsSL "${WT_BASE:-https://start.wikitata.com}/onboard-linux.sh")
fi

# ── Colors + Symbols ─────────────────────────────────────────────────────────

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; B='\033[0;34m'
C='\033[0;36m'; D='\033[2m'; BD='\033[1m'; RST='\033[0m'
OK="${G}✓${RST}"
FAIL="${R}✗${RST}"
WARN="${Y}⚠${RST}"
ARROW="${C}→${RST}"
BAR="${D}═══════════════════════════════════════════════════════════════${RST}"

STEP=0
TOTAL=11
ERRORS=0
SKIPPED=0

# ── Open the landing page if no username provided (gate first) ───────────────
if [ -z "${WT_USERNAME:-}" ] && [ -z "${1:-}" ]; then
  open "https://my.wikitata.com/setup" 2>/dev/null
  echo ""
  echo -e "  ${BD}Opening the wikiTaTa setup page in your browser...${RST}"
  echo -e "  ${D}Enter your username and invite code there first.${RST}"
  echo -e "  ${D}The browser will give you the right command to run here.${RST}"
  echo ""
  exit 0
fi

# ── Opening brief ────────────────────────────────────────────────────────────

clear
printf '\n\n'
echo -e "  ${BAR}"
echo -e "  ${BD}wikiTaTa Developer Setup${RST}                          ${D}step 0 of $TOTAL${RST}"
echo -e "  ${BAR}"
printf '\n'
echo -e "  ${BD}What this script does — and why every step is needed:${RST}"
printf '\n'
echo -e "  ${C}→${RST}  ${BD}Installs the tools Claude Code depends on${RST}"
echo -e "  ${D}     Node.js, Homebrew, and Xcode CLT are the runtime foundation.${RST}"
echo -e "  ${D}     Claude Code and the wikiTaTa MCP server both run on Node.js.${RST}"
printf '\n'
echo -e "  ${C}→${RST}  ${BD}Makes sure Google Chrome is installed${RST}"
echo -e "  ${D}     wikiTaTa and its browser helper are built and tested on Chrome.${RST}"
printf '\n'
echo -e "  ${C}→${RST}  ${BD}Offers the wikiTaTa desktop app (optional)${RST}"
echo -e "  ${D}     wikiTaTa in its own window, kept up to date by itself.${RST}"
printf '\n'
echo -e "  ${C}→${RST}  ${BD}Connects your machine to GitHub + installs wikiTaTa shell helpers${RST}"
echo -e "  ${D}     The wikiTaTa MCP itself is hosted (HTTPS, mcp.wikitata.com) — nothing runs${RST}"
echo -e "  ${D}     locally. SSH gives your machine trusted access to your own code.${RST}"
printf '\n'
echo -e "  ${C}→${RST}  ${BD}Registers your workspace with Claude Code${RST}"
echo -e "  ${D}     Claude needs to know where the MCP server is and who you are.${RST}"
echo -e "  ${D}     Without this, Claude is a generic AI — not your AI.${RST}"
printf '\n'
echo -e "  ${C}→${RST}  ${BD}Installs shell shortcuts and sets up self-monitoring${RST}"
echo -e "  ${D}     wt_start / wt_end / wt_autolink speed up your daily workflow.${RST}"
echo -e "  ${D}     Self-heal lets us diagnose and fix issues remotely.${RST}"
printf '\n'
echo -e "  ${D}Every step checks if something is already installed before touching it.${RST}"
echo -e "  ${D}Safe to re-run. Fresh machine takes about 5 minutes.${RST}"
printf '\n'
echo -e "  ${BAR}"
printf '\n'
read -p "  Ready to begin? Press Enter... " _unused

# ── Helpers ──────────────────────────────────────────────────────────────────

# Y/N consent for anything this script downloads or installs (Todd, S1115). Default = no.
ask_yn() {
  local _yn
  printf "  ${Y}${BD}%s${RST} [y/N]: " "$1"
  read -r _yn </dev/tty
  case "$_yn" in y|Y|yes|YES|Yes) return 0 ;; *) return 1 ;; esac
}

step_header() {
  STEP=$((STEP + 1))
  clear
  printf '\n\n\n'
  echo -e "  ${BAR}"
  echo -e "  ${BD}wikiTaTa Developer Setup${RST}                          ${D}step $STEP of $TOTAL${RST}"
  echo -e "  ${BAR}"
  printf '\n'
  echo -e "  ${BD}${C}$1${RST}"
  echo -e "  ${D}$2${RST}"
  printf '\n'
}

ok()    { echo -e "  ${OK}  $1"; }
fail()  { echo -e "  ${FAIL}  $1"; ERRORS=$((ERRORS + 1)); }
warn()  { echo -e "  ${WARN}  $1"; }
info()  { echo -e "  ${ARROW}  $1"; }
dim()   { echo -e "  ${D}$1${RST}"; }
blank() { echo ""; }

wait_for_enter() {
  blank
  echo -e "  ${D}────────────────────────────────────────────────${RST}"
  read -p "  Press Enter to continue... " _unused
}

has() { command -v "$1" >/dev/null 2>&1; }

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Xcode Command Line Tools
# ═══════════════════════════════════════════════════════════════════════════════

step_header "Xcode Command Line Tools" "Git and build essentials for macOS"
dim "Why: Git is bundled here — needed to clone the wikiTaTa repo and pull updates."
dim "     Also provides the C compiler some npm packages need to build native modules."
blank

if xcode-select -p >/dev/null 2>&1; then
  ok "Xcode is already installed. Great!"
  ok "$(git --version)"
  dim ""
  dim "Moving on to the next step..."
  sleep 1.5
else
  info "Xcode isn't installed yet — let's fix that."
  blank
  xcode-select --install 2>/dev/null
  blank
  echo -e "  ${Y}${BD}A system popup should appear.${RST}"
  echo -e "  ${Y}Click Install and wait for it to finish (2-5 minutes).${RST}"
  blank
  read -p "  Press Enter when the install is done... " _unused
  blank

  if xcode-select -p >/dev/null 2>&1; then
    ok "Xcode installed successfully!"
    ok "$(git --version)"
  else
    fail "Xcode install didn't complete — try running xcode-select --install manually"
    wait_for_enter
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Homebrew
# ═══════════════════════════════════════════════════════════════════════════════

step_header "Homebrew" "macOS package manager — makes installing everything else clean"
dim "Why: The safest way to install Node.js and CLI tools on a Mac. Keeps things"
dim "     updatable and out of system directories. Most developers already have it."
blank

if has brew; then
  ok "Homebrew is already installed. Nice!"
  dim "$(brew --version | head -1)"
  dim ""
  dim "Moving on to the next step..."
  sleep 1.5
else
  info "Homebrew isn't installed yet — let's get it."
  dim "This is the macOS package manager. Makes everything else easy."
  blank
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  blank

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile 2>/dev/null
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

  if has brew; then
    ok "Homebrew installed successfully!"
    dim "$(brew --version | head -1)"
  else
    fail "Homebrew not found after install"
    info "Try opening a new terminal tab and running: brew --version"
    wait_for_enter
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2b: Google Chrome (S1115, task dd2ad641) — checked by bundle id, installed from Google's image if missing
# ═══════════════════════════════════════════════════════════════════════════════

step_header "Google Chrome" "The browser wikiTaTa and its helper extension are built and tested on"
dim "Why: wikiTaTa runs in your browser, and the wikiTaTa browser helper is a Chrome"
dim "     extension. Checking now means the rest of setup opens in the right place."
blank

CHROME_DMG_URL="https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
find_chrome() { # prints the path of the Chrome app (by bundle id, so a renamed copy counts)
  local a
  for a in "/Applications/Google Chrome.app" "$HOME/Applications/Google Chrome.app" /Applications/*.app "$HOME"/Applications/*.app; do
    [ -d "$a" ] || continue
    [ "$(defaults read "$a/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "com.google.Chrome" ] && { echo "$a"; return 0; }
  done
  return 1
}
chrome_version() { defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null; }

if [ "$(uname -s)" != "Darwin" ]; then
  warn "Not a Mac — skipping the Chrome check here."
  sleep 1.5
elif CHROME_APP="$(find_chrome)"; then
  ok "Google Chrome is already installed — $(chrome_version "$CHROME_APP")"
  dim "$CHROME_APP"
  dim ""
  dim "Moving on to the next step..."
  sleep 1.5
elif ! ask_yn "Google Chrome isn't installed. Download and install it now (about 280 MB, from Google)?"; then
  warn "Skipped — you can install Chrome any time from https://www.google.com/chrome"
  SKIPPED=$((SKIPPED + 1))
  sleep 1.5
else
  info "Downloading Google Chrome from Google now."
  blank
  CHROME_TMP="$(mktemp -d /tmp/wt-chrome.XXXXXX)"
  CHROME_MNT="$CHROME_TMP/mnt"
  if curl -fL --progress-bar -o "$CHROME_TMP/googlechrome.dmg" "$CHROME_DMG_URL" \
     && hdiutil attach -nobrowse -quiet -mountpoint "$CHROME_MNT" "$CHROME_TMP/googlechrome.dmg"; then
    if ! cp -R "$CHROME_MNT/Google Chrome.app" /Applications/ 2>/dev/null; then
      info "Your account can't write to /Applications — installing to ~/Applications instead."
      mkdir -p "$HOME/Applications" && cp -R "$CHROME_MNT/Google Chrome.app" "$HOME/Applications/"
    fi
    hdiutil detach -quiet "$CHROME_MNT" 2>/dev/null
  fi
  rm -rf "$CHROME_TMP"
  blank

  if CHROME_APP="$(find_chrome)"; then
    ok "Google Chrome installed — $(chrome_version "$CHROME_APP")"
    dim "$CHROME_APP"
  else
    fail "Chrome didn't install — download it from https://www.google.com/chrome and re-run this script"
    wait_for_enter
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2c: wikiTaTa desktop app — OPTIONAL (S1115, task 140b60b2). Feed = signed-in route on my.wikitata.com
# (S1122, task e9610101): the session token from /i/<code> rides as the wt_tok cookie; the feed hands back a
# 10-minute signed link to the private bucket, fetched with no credential.
# ═══════════════════════════════════════════════════════════════════════════════

step_header "wikiTaTa desktop app (optional)" "wikiTaTa in its own window — it keeps itself up to date"
dim "Why: the same wikiTaTa you use in the browser, in its own app window. When a new"
dim "     version ships it installs it and switches over while you are away. You can skip this."
blank

WT_DESKTOP_FEED="https://my.wikitata.com/api/wt/desktop/latest-mac-arm64.json"
find_wt_app() {
  local a
  for a in "/Applications/wikiTaTa.app" "$HOME/Applications/wikiTaTa.app" /Applications/*.app "$HOME"/Applications/*.app; do
    [ -d "$a" ] || continue
    [ "$(plutil -extract CFBundleIdentifier raw "$a/Contents/Info.plist" 2>/dev/null)" = "com.wikitata.desktop" ] && { echo "$a"; return 0; }
  done
  return 1
}

if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
  warn "The desktop app is published for Apple silicon Macs only right now — skipping."
  sleep 1.5
elif WT_APP="$(find_wt_app)"; then
  ok "wikiTaTa desktop app is already installed — $(plutil -extract CFBundleShortVersionString raw "$WT_APP/Contents/Info.plist" 2>/dev/null)"
  dim "It updates itself. Moving on to the next step..."
  sleep 1.5
elif [ -z "${WT_JWT:-}" ]; then
  warn "The desktop app download needs your sign-in — run the command from https://my.wikitata.com/setup to get it."
  SKIPPED=$((SKIPPED + 1))
  sleep 1.5
elif ! ask_yn "Install the wikiTaTa desktop app (about 120 MB download)?"; then
  info "Skipped — you can use wikiTaTa in Chrome at https://my.wikitata.com"
  SKIPPED=$((SKIPPED + 1))
  sleep 1.5
else
  WT_TMP="$(mktemp -d /tmp/wt-desktop.XXXXXX)"
  WT_OK=0
  # Token goes in via curl's stdin config (printf is a builtin) — never in argv, where ps would show it.
  if printf 'header = "Cookie: wt_tok=%s"\n' "$WT_JWT" | curl -fsSL -K - -o "$WT_TMP/latest.json" "$WT_DESKTOP_FEED"; then
    WT_VER="$(plutil -extract version raw "$WT_TMP/latest.json" 2>/dev/null)"
    WT_URL="$(plutil -extract url raw "$WT_TMP/latest.json" 2>/dev/null)"
    WT_SHA="$(plutil -extract sha256 raw "$WT_TMP/latest.json" 2>/dev/null)"
    info "Downloading wikiTaTa $WT_VER ..."
    if [ -n "$WT_URL" ] && curl -fL --progress-bar -o "$WT_TMP/app.zip" "$WT_URL" \
       && [ "$(shasum -a 256 "$WT_TMP/app.zip" | cut -d' ' -f1)" = "$WT_SHA" ] \
       && ditto -x -k "$WT_TMP/app.zip" "$WT_TMP/x" \
       && [ "$(plutil -extract CFBundleIdentifier raw "$WT_TMP/x/wikiTaTa.app/Contents/Info.plist" 2>/dev/null)" = "com.wikitata.desktop" ] \
       && codesign --verify --deep --strict "$WT_TMP/x/wikiTaTa.app" 2>/dev/null; then
      xattr -dr com.apple.quarantine "$WT_TMP/x/wikiTaTa.app" 2>/dev/null
      if ditto "$WT_TMP/x/wikiTaTa.app" /Applications/wikiTaTa.app 2>/dev/null; then WT_OK=1
      else
        info "Your account can't write to /Applications — installing to ~/Applications instead."
        mkdir -p "$HOME/Applications" && ditto "$WT_TMP/x/wikiTaTa.app" "$HOME/Applications/wikiTaTa.app" && WT_OK=1
      fi
    fi
  fi
  rm -rf "$WT_TMP"
  blank
  if [ "$WT_OK" = 1 ] && WT_APP="$(find_wt_app)"; then
    ok "wikiTaTa desktop app installed — $(plutil -extract CFBundleShortVersionString raw "$WT_APP/Contents/Info.plist" 2>/dev/null)"
    dim "$WT_APP (download checked against its published SHA-256)"
    open "$WT_APP" 2>/dev/null
  else
    fail "The desktop app didn't install (download, checksum or signature check failed). wikiTaTa still works in Chrome."
    wait_for_enter
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Node.js
# ═══════════════════════════════════════════════════════════════════════════════

step_header "Node.js" "Required for Claude Code, the setup wizard, and all CLI tools"
dim "Why: Claude Code runs on Node.js. The wikiTaTa MCP server — the bridge between"
dim "     Claude and your workspace — also runs on Node.js. Both need it at runtime."
blank

if has node; then
  NODE_V=$(node -v)
  ok "Node.js is already installed — $NODE_V. Perfect!"
  dim "npm $(npm -v)"
  dim ""
  dim "Moving on to the next step..."
  sleep 1.5
else
  if has brew; then
    info "Node.js isn't installed yet — installing via Homebrew now."
    dim "This powers Claude Code and all the CLI tools."
    blank
    brew install node
    blank

    if has node; then
      ok "Node.js installed — $(node -v)"
      dim "npm $(npm -v)"
    else
      fail "Node.js install failed — try: brew install node"
      wait_for_enter
    fi
  else
    fail "Can't install Node.js — Homebrew isn't available"
    info "Go back and install Homebrew first, then re-run this script"
    wait_for_enter
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: CLI Tools (Claude Code, Supabase, Vercel)
# ═══════════════════════════════════════════════════════════════════════════════

step_header "CLI Tools" "Claude Code, Supabase CLI, Vercel CLI"
dim "Why: Claude Code is the AI assistant you'll use every day. Supabase and Vercel"
dim "     CLIs let you manage your database and deploy your work from the terminal."
blank

if ! has npm; then
  fail "npm not found — Node.js is required for this step"
else
  # Claude Code
  if has claude; then
    ok "Claude Code — already installed"
  else
    info "Installing Claude Code — this is the AI assistant."
    npm install -g @anthropic-ai/claude-code 2>&1 | tail -2
    has claude && ok "Claude Code installed!" || fail "Claude Code install failed"
  fi

  # Supabase CLI
  if has supabase; then
    ok "Supabase CLI — already installed"
  else
    info "Installing Supabase CLI — database tools."
    if has brew; then
      brew install supabase/tap/supabase 2>&1 | tail -2
    else
      npm install -g supabase 2>&1 | tail -2
    fi
    has supabase && ok "Supabase CLI installed!" || fail "Supabase CLI install failed"
  fi

  # Vercel CLI
  if has vercel; then
    ok "Vercel CLI — already installed"
  else
    info "Installing Vercel CLI — deployment tools."
    npm install -g vercel@latest 2>&1 | tail -2
    has vercel && ok "Vercel CLI installed!" || fail "Vercel CLI install failed"
  fi

  blank
  ok "All CLI tools ready."
fi

wait_for_enter

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: Identity
# ═══════════════════════════════════════════════════════════════════════════════

step_header "Your Identity" "wikiTaTa username — assigned to you when you were invited"
dim "Why: Your username is how wikiTaTa recognizes you across every machine and"
dim "     session. It's embedded in your Claude config so Claude knows who you are."
blank

if [ -n "${WT_USERNAME:-}" ]; then
  ok "Username from environment: $WT_USERNAME"
else
  blank
  read -p "  Your wikiTaTa username: " WT_USERNAME
  blank

  if [ -z "$WT_USERNAME" ]; then
    fail "Username required. Check your invite from the wikiTaTa team."
    exit 1
  fi
  ok "Username: $WT_USERNAME"
fi

wait_for_enter

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: SSH Key for GitHub
# ═══════════════════════════════════════════════════════════════════════════════

step_header "SSH Key for GitHub" "Required to clone the private wikiTaTa repo"
dim "Why: The wikiTaTa repo is private. SSH lets your machine prove its identity to"
dim "     GitHub without a password on every pull or clone. One-time setup."
blank

SSH_KEY=""
if [ -d "$HOME/.ssh" ]; then
  for candidate in "$HOME/.ssh/"*; do
    [ -f "$candidate" ] || continue
    case "$candidate" in
      *.pub|*/known_hosts*|*/config|*/authorized_keys|*/environment) continue ;;
    esac
    if head -1 "$candidate" 2>/dev/null | grep -qi "PRIVATE KEY"; then
      SSH_KEY="$candidate"
      break
    fi
  done
fi

if [ -n "$SSH_KEY" ]; then
  ok "SSH key found: $(basename $SSH_KEY)"
  dim "$(ls -la $SSH_KEY)"
  blank

  info "Testing GitHub connection..."
  echo -e "  ${D}(trying git@github.com and any SSH aliases)${RST}"
  SSH_VERIFIED=false

  for gh_host in github.com $(grep -i 'Host github' "$HOME/.ssh/config" 2>/dev/null | awk '{print $2}'); do
    SSH_OUT=$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 "git@${gh_host}" 2>&1 || true)
    if echo "$SSH_OUT" | grep -qi "successfully authenticated"; then
      ok "GitHub SSH verified via $gh_host"
      dim "$SSH_OUT"
      SSH_VERIFIED=true
      break
    fi
  done

  if [ "$SSH_VERIFIED" = true ]; then
    dim ""
    dim "Moving on to the next step..."
    sleep 1.5
  else
    warn "SSH key exists but GitHub didn't recognize it."
    dim "$SSH_OUT"
    blank
    echo -e "  ${Y}Your public key needs to be added to GitHub.${RST}"
    echo -e "  ${Y}Here it is — copy this entire line:${RST}"
    blank
    echo -e "  ${G}$(cat ${SSH_KEY}.pub)${RST}"
    blank
    info "Send this key to the wikiTaTa team to get access."
    info "Or add it yourself at: https://github.com/settings/keys"
    blank
    read -p "  Press Enter after you've added the key to GitHub... " _unused
    blank

    SSH_OUT2=$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 git@github.com 2>&1 || true)
    if echo "$SSH_OUT2" | grep -qi "successfully authenticated"; then
      ok "GitHub SSH connection verified!"
    else
      fail "Still not connecting. Ask the wikiTaTa team for help."
      dim "$SSH_OUT2"
    fi
    wait_for_enter
  fi
else
  info "No SSH key found — let's create one."
  blank

  GIT_EMAIL="${WT_GIT_EMAIL:-}"
  if [ -z "$GIT_EMAIL" ]; then
    read -p "  Your email (for the SSH key): " GIT_EMAIL
    blank
  fi

  SSH_KEY="$HOME/.ssh/id_ed25519"   # S1216: this branch ran with SSH_KEY="" (no key found), so ssh-keygen saved to "" and failed
  mkdir -p "$(dirname "$SSH_KEY")" && chmod 700 "$(dirname "$SSH_KEY")"   # a fresh account has no ~/.ssh
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
  blank

  if [ -f "$SSH_KEY" ]; then
    ok "SSH key generated!"
    blank

    eval "$(ssh-agent -s)" >/dev/null 2>&1
    ssh-add "$SSH_KEY" 2>/dev/null

    echo -e "  ${Y}${BD}Now add this key to GitHub.${RST}"
    echo -e "  ${Y}Copy the entire line below:${RST}"
    blank
    echo -e "  ${G}$(cat ${SSH_KEY}.pub)${RST}"
    blank
    cat "${SSH_KEY}.pub" | pbcopy 2>/dev/null && dim "(Also copied to clipboard)"
    blank
    info "Go to: https://github.com/settings/keys"
    info "Click 'New SSH Key', paste, and save."
    blank
    read -p "  Press Enter after you've added the key to GitHub... " _unused
    blank

    info "Testing GitHub connection..."
    SSH_OUT=$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 git@github.com 2>&1 || true)
    if echo "$SSH_OUT" | grep -qi "successfully authenticated"; then
      ok "GitHub SSH connection verified!"
    else
      warn "GitHub didn't recognize the key yet."
      dim "$SSH_OUT"
      info "Double-check you pasted the key at github.com/settings/keys"
      info "You can try again later — the clone step will tell us."
    fi
  else
    fail "SSH key generation failed"
  fi
  wait_for_enter
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: Clone wikiTaTa + Configure Claude Code
# ═══════════════════════════════════════════════════════════════════════════════

step_header "Connect Claude to wikiTaTa" "Register the HTTPS MCP + install your shell helpers"
dim "Why: Claude reaches your workspace through the wikiTaTa MCP over HTTPS (mcp.wikitata.com) —"
dim "     a hosted server; nothing runs on your machine. This step registers that connection,"
dim "     then installs your shell helpers + self-heal. Sign-in opens in your browser on first launch."
blank

HOME_DIR="$HOME"
mkdir -p "$HOME_DIR/git"

# Clone
if [ -d "$HOME_DIR/git/wikitata" ]; then
  ok "Repo is already cloned. Pulling latest..."
  cd "$HOME_DIR/git/wikitata" && git pull 2>/dev/null
  if [ -f "$HOME_DIR/git/wikitata/shell-scripts/wikitata_env.sh" ]; then
    ok "wikiTaTa shell helpers present"
  else
    warn "shell-scripts missing — may need a fresh clone"
  fi
else
  info "Cloning the wikiTaTa repo — this is where your tools live."
  # S1216: never block on a credential prompt. On a fresh Mac the HTTPS clone of this PRIVATE repo opened Git
  # Credential Manager / a username prompt and the installer hung there (measured in a fresh macOS VM). The clone is
  # OPTIONAL now — the MCP is hosted and the golden bundle needs no checkout — so it runs non-interactively and a
  # miss is a warning with the command to run later.
  CLONED=false
  for gh_host in $(grep -i 'Host github' "$HOME/.ssh/config" 2>/dev/null | awk '{print $2}') github.com; do
    if GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15" \
       git clone "git@${gh_host}:wikiTaTa/wikitata.git" "$HOME_DIR/git/wikitata" 2>/dev/null; then
      ok "Cloned via SSH ($gh_host)"
      CLONED=true
      break
    fi
  done
  if [ "$CLONED" = false ]; then
    if GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git -c credential.interactive=false clone https://github.com/wikiTaTa/wikitata.git "$HOME_DIR/git/wikitata" </dev/null 2>/dev/null; then
      ok "Cloned via HTTPS"
      warn "SSH clone failed — HTTPS works but you'll need SSH for push access later"
    else
      warn "Repo not cloned (your GitHub key isn't set up yet) — optional: wikiTaTa itself works without it."
      dim "Later, after adding your key at github.com/settings/keys: git clone git@github.com:wikiTaTa/wikitata.git ~/git/wikitata"
    fi
  fi
fi

# No local MCP server to build — the wikiTaTa MCP is hosted over HTTPS (mcp.wikitata.com).
# The clone above provides only the shell helpers + self-heal updater.

blank

# Claude config
mkdir -p "$HOME_DIR/.claude"
# wtu-5: new tenants run against the WT_USER content DB (lobby-issued ES256 sessions).
# Identity/auth flows through the lobby IdP (auth.wikitata.com); content REST hits WT_USER.
WT_SB_URL_TENANT="https://qfvnynyjeydxchtrwznk.supabase.co"
WT_SB_KEY_TENANT="sb_publishable_xizlPDZaiw3dusGhPqul3A_28vmrpfu"
# Data plane: tenant (lobby/qfvnyn, default) or super (platform/onoujm). Pass
# WT_PLANE=super to install this machine under a platform/superuser identity (an
# admin's own box). The zshrc WT_SB_URL already targets onoujm; this flips the MCP
# too, and the lobby device-activation below auto-skips when there is no WT_JWT.
# Publishable keys only here — full superuser power comes from the keychain
# (wt-superuser-bootstrap), never from a baked secret. Canon: card 8ddf8981.
WT_PLANE="${WT_PLANE:-tenant}"
WT_SB_URL_SUPER="https://onoujmfhlrhvcqzjniei.supabase.co"
WT_SB_KEY_SUPER="sb_publishable_dgNg9YFvNEDlvC4qXPrJcg_4uEtEQUT"
if [ "$WT_PLANE" = "super" ]; then
  WT_SB_URL_ACTIVE="$WT_SB_URL_SUPER"; WT_SB_KEY_ACTIVE="$WT_SB_KEY_SUPER"
  dim "Plane: SUPERUSER (platform / onoujm) — WT_USER=$WT_USERNAME"
else
  WT_SB_URL_ACTIVE="$WT_SB_URL_TENANT"; WT_SB_KEY_ACTIVE="$WT_SB_KEY_TENANT"
fi

# The MCP registration is made in ONE place, wt-connect.sh (run below with the golden bundle, S1253, task 81e3f575):
# it skips `claude mcp add` when your Claude account already has the claude.ai wikiTaTa connector, and otherwise adds
# the user-scope HTTPS entry to ~/.claude.json. First Claude session opens your browser to sign in (OAuth).
has claude || warn "Claude Code not found — the wikiTaTa MCP is registered when you re-run this after installing it"

# ── wikiTaTa user-switch helpers (install to ~/.local/bin) ───────────────────
# wt-switch-user: flip the MCP (+ shell) to any user/plane later (tenant or super).
# wt-superuser-bootstrap: tier-2 keychain check for full superuser power.
mkdir -p "$HOME_DIR/.local/bin"
for _tool in wt-switch-user wt-superuser-bootstrap; do
  if curl -fsSL "https://start.wikitata.com/$_tool" -o "$HOME_DIR/.local/bin/$_tool" 2>/dev/null; then
    chmod +x "$HOME_DIR/.local/bin/$_tool" && ok "$_tool installed (~/.local/bin)"
  else
    warn "$_tool fetch deferred — later: curl -fsSL https://start.wikitata.com/$_tool -o ~/.local/bin/$_tool && chmod +x ~/.local/bin/$_tool"
  fi
done
grep -q '/.local/bin' "$HOME_DIR/.zshrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME_DIR/.zshrc"

if [ ! -f "$HOME_DIR/.claude/settings.json" ]; then
  dim "Writing ~/.claude/settings.json"
  cat > "$HOME_DIR/.claude/settings.json" << 'SEOF'
{
  "permissions": {
    "allow": [
      "Bash", "Read", "Write", "Edit", "Glob", "Grep",
      "Agent", "WebFetch", "WebSearch", "mcp__*"
    ]
  }
}
SEOF
  ok "settings.json"
else
  ok "settings.json (exists — kept)"
fi


# ── Seat sign-in (S1216, tasks af10e2bc / f2b13ddf) ─────────────────────────────
# When the /i/<code> shim from my.wikitata.com/setup provided a lobby JWT (WT_JWT — the WorkOS sign-in), ONE activate
# exchange registers the device + self-heal hash and returns this seat's CACP token. The token goes straight into the
# login keychain as WT_CACP_TOKEN — the item every golden hook reads (it used to land under `wikitata-cacp`, which no
# hook reads, so the seat looked tokenless). It is written with `security -i` fed on STDIN (printf is a shell builtin),
# so it is never in any process's argv. The golden bootstrap then pulls the rest of this seat's secrets with it.
SH_HASH=""; WT_DEVICE_ID=""; DEV_REGISTERED="false"; SH_REGISTERED="false"
wt_activate_seat() {
  if ! /usr/bin/security find-generic-password -a "$USER" -s wt-selfheal-token >/dev/null 2>&1; then
    printf 'add-generic-password -U -a "%s" -s wt-selfheal-token -w "%s"\n' "$USER" "$(openssl rand -hex 32)" \
      | /usr/bin/security -i >/dev/null 2>&1 && ok "Self-heal device token created (login keychain)" \
      || warn "Keychain write failed — self-heal token pending"
  fi
  local tok
  tok="$(/usr/bin/security find-generic-password -a "$USER" -s wt-selfheal-token -w 2>/dev/null || true)"
  [ -n "$tok" ] && SH_HASH=$(printf '%s' "$tok" | shasum -a 256 | cut -d' ' -f1)
  tok=""
  if [ -z "${WT_JWT:-}" ]; then
    if /usr/bin/security find-generic-password -a "$USER" -s WT_CACP_TOKEN >/dev/null 2>&1; then
      ok "Seat token already in the keychain (WT_CACP_TOKEN)"
    else
      warn "No sign-in token in this run — start from https://my.wikitata.com/setup to sign in, and this seat gets its token automatically"
    fi
    return 0
  fi
  local payload resp cacp
  payload=$(WT_JWT="$WT_JWT" WT_USERNAME="$WT_USERNAME" SH_HASH="$SH_HASH" python3 -c '
import json, os, socket
print(json.dumps({
  "mode": "setup",
  "jwt": os.environ.get("WT_JWT", ""),
  "username": os.environ.get("WT_USERNAME", ""),
  "selfheal_token_hash": os.environ.get("SH_HASH", ""),
  "hostname": socket.gethostname(),
  "platform": "darwin",
  "device_label": socket.gethostname().split(".")[0],
}))' 2>/dev/null)
  resp=$(printf '%s' "$payload" | curl -sf --max-time 25 \
    -X POST "https://onoujmfhlrhvcqzjniei.supabase.co/functions/v1/activate" \
    -H "Content-Type: application/json" --data-binary @- 2>/dev/null || true)
  payload=""
  if [ -z "$resp" ]; then
    warn "Activation exchange unreachable — re-run setup from https://my.wikitata.com/setup to finish signing this seat in"
    return 0
  fi
  WT_DEVICE_ID=$(printf '%s' "$resp" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("device_id") or "")' 2>/dev/null || echo "")
  DEV_REGISTERED=$(printf '%s' "$resp" | python3 -c 'import sys,json;d=json.load(sys.stdin);print("true" if d.get("device_registered") else "false")' 2>/dev/null || echo "false")
  SH_REGISTERED=$(printf '%s' "$resp" | python3 -c 'import sys,json;d=json.load(sys.stdin);print("true" if d.get("selfheal_registered") else "false")' 2>/dev/null || echo "false")
  cacp=$(printf '%s' "$resp" | python3 -c 'import sys,json,re;t=json.load(sys.stdin).get("cacp_token") or "";print(t if re.fullmatch(r"[0-9a-f]{32,128}",t) else "")' 2>/dev/null || echo "")
  resp=""
  if [ -n "$cacp" ]; then
    printf 'add-generic-password -U -a "%s" -s WT_CACP_TOKEN -l "wikiTaTa seat token" -w "%s"\n' "$USER" "$cacp" \
      | /usr/bin/security -i >/dev/null 2>&1 \
      && /usr/bin/security find-generic-password -a "$USER" -s WT_CACP_TOKEN >/dev/null 2>&1 \
      && ok "Seat token stored (login keychain: WT_CACP_TOKEN)" \
      || warn "Seat token keychain write failed — re-run setup from https://my.wikitata.com/setup"
  else
    warn "Seat token not delivered by the activation exchange — re-run setup from https://my.wikitata.com/setup"
  fi
  cacp=""
  [ "$DEV_REGISTERED" = "true" ] && ok "Device registered with wikiTaTa ($WT_DEVICE_ID)"
  [ "$SH_REGISTERED" = "true" ] && ok "Self-heal token hash registered server-side"
  return 0
}
wt_activate_seat

# ~/.claude/CLAUDE.md is no longer written here (S1190, task 0d5d37bd): the golden bundle renders it per
# seat from wikiTaTa/wikitata wt-mcp-server/claude-md/. wt-connect.sh is the one installer for that plumbing.
dim "Installing the golden bundle (CLAUDE.md, hooks, skills) via wt-connect.sh"
if curl -fsSL --max-time 30 "${WT_BASE:-https://start.wikitata.com}/wt-connect.sh" | bash -s "$WT_USERNAME"; then
  ok "golden bundle + CLAUDE.md"
else
  warn "wt-connect.sh failed — re-run: curl -fsSL https://start.wikitata.com/wt-connect.sh | bash -s $WT_USERNAME"
fi

wait_for_enter

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8: Shell Tools + Environment
# ═══════════════════════════════════════════════════════════════════════════════

step_header "Shell Tools" "wt_autolink, wt_start, wt_end + environment variables"
dim "Why: wt_start / wt_end / wt_autolink are the shortcuts you'll use every session."
dim "     Environment variables (WT_ACTOR, WT_SB_URL) let scripts know who you are"
dim "     without you having to type credentials each time."
blank

ZSHRC="$HOME_DIR/.zshrc"
[ -f "$ZSHRC" ] || touch "$ZSHRC"

# Shell baseline
BASELINE_MARKER="# wt-baseline-configured"
if ! grep -q "$BASELINE_MARKER" "$ZSHRC" 2>/dev/null; then
  dim "Configuring zsh baseline..."
  cat >> "$ZSHRC" << 'ZEOF'

# wt-baseline-configured
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt NO_CLOBBER CORRECT
autoload -Uz compinit && compinit -u
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' %F{yellow}(%b)%f'
setopt PROMPT_SUBST
PROMPT='%F{cyan}%1~%f${vcs_info_msg_0_} %F{white}$%f '
export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export EDITOR="nano"
alias ll='ls -lahG'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -15'
alias gp='git push'
ZEOF
  ok "zsh baseline (history, completion, prompt, aliases)"
else
  ok "zsh baseline already configured"
fi

# Shell tools
SHELL_SCRIPT="$HOME_DIR/git/wikitata/shell-scripts/wikitata_env.sh"
if [ -f "$SHELL_SCRIPT" ]; then
  if ! grep -q "wikitata_env.sh" "$ZSHRC" 2>/dev/null; then
    echo "source $SHELL_SCRIPT 2>/dev/null" >> "$ZSHRC"
    ok "wikitata_env.sh added to .zshrc"
  else
    ok "wikitata_env.sh already in .zshrc"
  fi
else
  warn "Shell scripts not found — will be available after repo update"
fi

# Env vars
if ! grep -q "WT_ACTOR" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" << ENVEOF
export WT_ACTOR=$WT_USERNAME
export WT_SB_URL=https://onoujmfhlrhvcqzjniei.supabase.co
export WT_OUTPUT_DIR=~/Downloads/claude-output
ENVEOF
  mkdir -p "$HOME_DIR/Downloads/claude-output"
  ok "WT environment variables"
else
  ok "WT environment variables already set"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SELF-HEAL + DEVICE ACTIVATION (cards ce413352 / 751f1c4d) — when the /i/<code>
# shim provided a lobby JWT (WT_JWT), ONE activate-edge-fn exchange registers the
# device + selfheal hash server-side AND delivers the CACP coordination token into
# the login keychain (S549: the anon bootstrap RPC is revoked; this is the only path).
# Without a JWT everything stages locally and the first Claude session finishes it.
# Token plaintext lives ONLY in the login keychain; only its sha256 crosses the wire.
# ═══════════════════════════════════════════════════════════════════════════════
step_header "Self-Heal Setup" "Remote diagnostics + allowlisted self-repair for this machine"
dim "Why: When something breaks (MCP loses connection, a token expires, a service"
dim "     restarts), self-heal detects it and fixes it — no manual script required."
dim "     A device token in your keychain proves this machine is yours."
blank

SH_DIR="$HOME_DIR/git/wikitata/tools/self-heal"
SH_CFG_DIR="$HOME_DIR/Library/Application Support/wikitata"
SH_PLIST="$HOME_DIR/Library/LaunchAgents/com.wikitata.selfheal.plist"

if [ ! -f "$SH_DIR/poller.js" ]; then
  warn "tools/self-heal not in repo checkout — self-heal skipped (git pull later + re-run)"
else
  # 1)+2) Device token + the activate exchange ran in step 7 (wt_activate_seat, S1216): the seat token must be in
  #    the keychain BEFORE the golden bootstrap runs, so it can pull this seat's secrets on the same pass.
  # 3) Config (device_id from the exchange when registered; otherwise the first
  #    Claude session fills it when it registers the device + token hash via MCP).
  SH_DEVICE_ID_OUT="PENDING_CLAUDE_REGISTRATION"
  [ "$DEV_REGISTERED" = "true" ] && [ -n "$WT_DEVICE_ID" ] && SH_DEVICE_ID_OUT="$WT_DEVICE_ID"
  mkdir -p "$SH_CFG_DIR"
  printf '{\n  "device_id": "%s",\n  "supabase_url": "%s",\n  "anon_key": "%s",\n  "poll_seconds": 30,\n  "burst_seconds": 5,\n  "units": {},\n  "repos": ["%s"],\n  "expected_keychain_keys": ["wt-selfheal-token"]\n}\n' \
    "$SH_DEVICE_ID_OUT" "$WT_SB_URL_TENANT" "$WT_SB_KEY_TENANT" "$HOME_DIR/git/wikitata" > "$SH_CFG_DIR/selfheal.json"
  ok "Self-heal config staged ($SH_CFG_DIR/selfheal.json)"

  # 4) Stage the pending hash ONLY if the exchange didn't register it already.
  if [ -n "$SH_HASH" ] && [ "$SH_REGISTERED" != "true" ]; then
    printf '%s\n' "$SH_HASH" > "$SH_CFG_DIR/selfheal-token-hash.pending"
    ok "Token hash staged for Claude registration"
  elif [ "$SH_REGISTERED" = "true" ]; then
    rm -f "$SH_CFG_DIR/selfheal-token-hash.pending" 2>/dev/null
  fi

  # 5) LaunchAgent. Fully registered (device + hash) → start the poller now;
  #    otherwise stage only (it would just log auth failures before registration).
  NODE_BIN="$(command -v node || true)"
  if [ -n "$NODE_BIN" ] && [ -f "$SH_DIR/com.wikitata.selfheal.plist" ]; then
    mkdir -p "$HOME_DIR/Library/LaunchAgents" "$HOME_DIR/Library/Logs"
    sed -e "s|__NODE__|$NODE_BIN|g" -e "s|__DIR__|$SH_DIR|g" -e "s|__HOME__|$HOME_DIR|g" \
      "$SH_DIR/com.wikitata.selfheal.plist" > "$SH_PLIST"
    if plutil -lint "$SH_PLIST" >/dev/null 2>&1; then
      if [ "$DEV_REGISTERED" = "true" ] && [ "$SH_REGISTERED" = "true" ]; then
        launchctl bootout "gui/$(id -u)/com.wikitata.selfheal" 2>/dev/null || true
        launchctl bootstrap "gui/$(id -u)" "$SH_PLIST" 2>/dev/null \
          && ok "Self-heal poller started (device registered this install)" \
          || warn "LaunchAgent staged but failed to start — first Claude session can start it"
      else
        ok "Self-heal LaunchAgent staged (starts after Claude registers this device)"
      fi
    else
      warn "LaunchAgent plist failed lint — self-heal poller not staged"
    fi
  fi
  if [ "$DEV_REGISTERED" = "true" ] && [ "$SH_REGISTERED" = "true" ]; then
    dim "Device, self-heal and CACP registration completed during install."
  else
    dim "First Claude session completes this: device registration + token-hash + poller start."
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════════════════

clear
printf '\n\n\n'
echo -e "  ${BAR}"
echo -e "  ${BD}wikiTaTa Developer Setup${RST}                          ${G}${BD}Complete${RST}"
echo -e "  ${BAR}"
printf '\n'

if [ "$ERRORS" -eq 0 ]; then
  echo -e "  ${G}${BD}All steps passed.${RST}"
else
  echo -e "  ${Y}${BD}$ERRORS issue(s) found${RST} — review the warnings above."
fi

if [ "$SKIPPED" -gt 0 ]; then
  dim "$SKIPPED step(s) were already done — skipped automatically."
fi

printf '\n'
echo -e "  ${BD}Files created:${RST}"
if claude mcp get wikitata >/dev/null 2>&1; then
  dim "  ~/.claude.json             wikiTaTa MCP (user scope, https://mcp.wikitata.com/mcp)"
elif claude mcp list 2>/dev/null | grep -qE '^claude\.ai [^:]+: https://mcp\.wikitata\.com/mcp'; then
  dim "  (no MCP entry needed)      wikiTaTa comes from the claude.ai connector on your Claude account"
else
  warn "wikiTaTa MCP is not registered — run: curl -fsSL https://start.wikitata.com/wt-connect.sh | bash -s $WT_USERNAME"
fi
dim "  ~/.claude/settings.json    Tool permissions + the golden hooks"
dim "  ~/.claude/CLAUDE.md        Universal bootstrap (rendered by the golden bundle)"

printf '\n'
echo -e "  ${BAR}"
printf '\n'
echo -e "  ${BD}What to do now:${RST}"
printf '\n'
echo -e "  ${BD}1.${RST} ${Y}${BD}Quit the Claude app completely (⌘Q) and open it again${RST}"
dim "     The app reads its PATH and hooks only when it starts — until then it cannot find Node."
dim "     (Not using the Claude app? Open a new terminal window and type: claude)"
echo -e "  ${BD}2.${RST} Then say:  ${C}${BD}Hello. Start session.${RST}"
printf '\n'
echo -e "  Claude will know who you are: ${G}${BD}$WT_USERNAME${RST}"
printf '\n'
echo -e "  ${BAR}"
printf '\n'

# Open browser to completion page
open "https://my.wikitata.com/setup?done=1&user=$WT_USERNAME" 2>/dev/null

blank
read -p "  Ready to launch Claude Code? (y/n) " LAUNCH
if [[ "$LAUNCH" =~ ^[Yy] ]]; then
  clear
  printf '\n'
  echo -e "  ${BAR}"
  echo -e "  ${BD}Launching Claude Code...${RST}"
  echo -e "  ${BAR}"
  echo -e "  ${D}Say: ${C}Hello. Start session.${RST}"
  printf '\n'
  claude
else
  printf '\n'
  echo -e "  ${D}When you're ready: quit the Claude app (⌘Q) and open it again, or open a new terminal and type:${RST}"
  echo -e "  ${C}${BD}claude${RST}   then say: ${C}${BD}Hello. Start session.${RST}"
  printf '\n'
fi
