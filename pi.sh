#!/bin/bash
# wikiTaTa - Raspberry Pi test rig bootstrap
# Diagnoses the Pi, then installs Tailscale via whichever path this OS actually supports.
# Usage:  curl -sL start.wikitata.com/pi.sh | bash

HOSTNAME_TS="pi-testrig"
LOG=/tmp/pi-diag.txt

say() { printf '%s\n' "$*"; }
hdr() { printf '\n=== %s ===\n' "$*"; }

{
hdr "OS RELEASE";      cat /etc/os-release 2>&1
hdr "DEBIAN VERSION";  cat /etc/debian_version 2>&1
hdr "KERNEL / ARCH";   uname -a 2>&1
hdr "DPKG ARCH";       dpkg --print-architecture 2>&1
hdr "PI MODEL";        tr -d '\0' < /proc/device-tree/model 2>/dev/null; echo
                       grep -E 'Revision|Hardware|Model|model name' /proc/cpuinfo 2>&1 | sort -u
hdr "CPU COUNT";       nproc 2>&1
hdr "MEMORY";          free -h 2>&1
hdr "DISK";            df -h / 2>&1
hdr "TAILSCALE PRESENT"; command -v tailscale tailscaled 2>&1; dpkg -l 2>/dev/null | grep -i tailscale
hdr "NETWORK";         ip -4 addr show 2>&1 | grep -E 'inet |^[0-9]'
hdr "DEFAULT ROUTE";   ip route 2>&1 | head -5
hdr "DNS";             grep -v '^#' /etc/resolv.conf 2>&1
hdr "TLS REACH";       curl -sS -m 15 -o /dev/null -w 'pkgs.tailscale.com http=%{http_code} tls_verify=%{ssl_verify_result}\n' https://pkgs.tailscale.com/stable/ 2>&1
hdr "DATE";            date 2>&1
hdr "SUDO";            sudo -n true 2>&1 && say "passwordless sudo OK"
hdr "WHOAMI";          whoami; id
hdr "APT SOURCES";     ls -la /etc/apt/sources.list.d/ 2>&1
hdr "TUN DEVICE";      lsmod 2>/dev/null | grep -i tun; ls -l /dev/net/tun 2>&1
hdr "INIT SYSTEM";     ps -p 1 -o comm= 2>&1
hdr "BROWSERS";        command -v chromium chromium-browser firefox-esr 2>&1
} 2>&1 | tee "$LOG"

CODENAME=$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-$(cat /etc/debian_version 2>/dev/null)}")
ARCH=$(dpkg --print-architecture 2>/dev/null)
ID_LIKE=$(. /etc/os-release 2>/dev/null; echo "${ID}")

hdr "INSTALL DECISION"
say "codename=$CODENAME  arch=$ARCH  id=$ID_LIKE"

if command -v tailscale >/dev/null 2>&1; then
  say "Tailscale already installed - skipping install."
else
  SUPPORTED="stretch buster bullseye bookworm trixie"
  if echo "$SUPPORTED" | grep -qw "$CODENAME"; then
    say "--> apt repo path (raspbian/$CODENAME)"
    sudo mkdir -p --mode=0755 /usr/share/keyrings
    if curl -fsSL "https://pkgs.tailscale.com/stable/raspbian/${CODENAME}.noarmor.gpg" \
         | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null \
    && curl -fsSL "https://pkgs.tailscale.com/stable/raspbian/${CODENAME}.tailscale-keyring.list" \
         | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null; then
      sudo apt-get update -y && sudo apt-get install -y tailscale
    else
      say "!! apt repo fetch failed - falling back to static binary"
      CODENAME="__static__"
    fi
  else
    say "--> codename '$CODENAME' has no Tailscale apt repo; using static binary"
    CODENAME="__static__"
  fi

  if [ "$CODENAME" = "__static__" ] || ! command -v tailscale >/dev/null 2>&1; then
    case "$ARCH" in
      arm64) TSARCH=arm64 ;;
      armhf) TSARCH=arm ;;
      amd64) TSARCH=amd64 ;;
      *)     TSARCH=arm ;;
    esac
    VER=$(curl -sS -m 20 'https://pkgs.tailscale.com/stable/?mode=json' 2>/dev/null \
          | tr ',' '\n' | grep -i 'TarballsVersion' | head -1 | sed 's/[^0-9.]//g')
    [ -z "$VER" ] && VER="1.86.2"
    TGZ="tailscale_${VER}_${TSARCH}.tgz"
    say "downloading $TGZ"
    cd /tmp || exit 1
    if curl -fsSL -o "$TGZ" "https://pkgs.tailscale.com/stable/${TGZ}"; then
      tar xzf "$TGZ"
      D="tailscale_${VER}_${TSARCH}"
      sudo cp "$D/tailscale" "$D/tailscaled" /usr/sbin/
      sudo cp "$D/systemd/tailscaled.service" /etc/systemd/system/ 2>/dev/null
      sudo cp "$D/systemd/tailscaled.defaults" /etc/default/tailscaled 2>/dev/null
      sudo systemctl daemon-reload
      sudo systemctl enable --now tailscaled
      say "static install complete"
    else
      say "!! static download FAILED - stopping. Send /tmp/pi-diag.txt"
      exit 1
    fi
  fi
fi

hdr "STARTING TAILSCALE"
sudo systemctl enable --now tailscaled 2>/dev/null
sudo tailscale up --ssh --hostname="$HOSTNAME_TS" --accept-dns=false 2>&1 | tee /tmp/pi-tsup.txt

hdr "RESULT"
if tailscale status >/dev/null 2>&1; then
  tailscale status 2>&1 | head -10
  say ""
  say "=================================================="
  say " DONE - Tailscale is UP. Hostname: $HOSTNAME_TS"
  say " Tailscale IP: $(tailscale ip -4 2>/dev/null)"
  say "=================================================="
else
  say ""
  say "=================================================="
  say " ACTION NEEDED - open the login URL printed above"
  say " in a browser on your Mac to authorise this Pi."
  say " Diagnostic saved to $LOG"
  say "=================================================="
fi
