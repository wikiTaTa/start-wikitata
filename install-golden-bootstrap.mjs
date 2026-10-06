#!/usr/bin/env node
// install-golden-bootstrap.mjs — THE onboarding SEED step (card 2aae217c, Part B). ONE instance for every installer:
// wt-connect.sh (macOS, which setup.sh hands off to), onboard-linux.sh and onboard-windows.ps1 all run exactly this file
// (S1216, task 03860769 ONB-FIX-2). It:
//   1. resolves the seat identity (WT_ACTOR / WT_USER / an existing ~/.claude/hooks/.cacp-user) — never a default user;
//   2. writes ~/.claude/hooks/.cacp-user, the file every golden hook and the bootstrap read (S1216, task 842cf2ad
//      ONB-FIX-5: no installer wrote it, so a fresh seat's heartbeat sent an empty user and got 401);
//   3. installs the self-healing bootstrap from the signed golden bundle (hash + signature verified, fail-closed);
//   4. wires it as a SessionStart hook (idempotent; never clobbers other hooks);
//   5. runs it twice with --apply (pass 1 can replace the bootstrap itself, pass 2 wires settings.json, renders
//      CLAUDE.md and pulls the seat's secrets) and exits non-zero unless the seat reports status=parity.
// On failure it prints the exact command to finish by hand.
import { createHash, createPublicKey, verify as edVerify } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { homedir } from "node:os";
import { dirname } from "node:path";

const PINNED_PUBLIC_KEY_B64 = "evwYUjg2dN326mRE9kp46DrmL2TcIrzsenZyPM0lcBw=";
const SB_URL = process.env.WT_SB_URL || "https://onoujmfhlrhvcqzjniei.supabase.co";
const SB_KEY = process.env.WT_SB_KEY || "sb_publishable_dgNg9YFvNEDlvC4qXPrJcg_4uEtEQUT";
// Identity: explicit only. The old default ("todd") rendered one person's CLAUDE.md layers onto anyone's machine.
const CACP_USER = `${homedir()}/.claude/hooks/.cacp-user`;
const fileUser = (() => { try { return readFileSync(CACP_USER, "utf8").trim(); } catch { return ""; } })();
const CALLER = (process.env.WT_ACTOR || process.env.WT_USER || fileUser || "").trim();
if (!/^[A-Za-z0-9_.@-]{1,80}$/.test(CALLER)) {
  console.error("⛔ no wikiTaTa username for this seat. Run the installer with your username, e.g.\n" +
    "   WT_ACTOR=<username> node install-golden-bootstrap.mjs");
  process.exit(1);
}
const CLAUDE_DIR = `${homedir()}/.claude`;
const BOOT_PATH = "bootstrap/wt-golden-bootstrap.mjs";
const sha256 = (b) => createHash("sha256").update(b).digest("hex");

function verifySig(manifest, sig_b64) {
  if (!sig_b64) return false;
  const der = Buffer.concat([Buffer.from("302a300506032b6570032100", "hex"), Buffer.from(PINNED_PUBLIC_KEY_B64, "base64")]);
  return edVerify(null, Buffer.from(manifest, "utf8"), createPublicKey({ key: der, format: "der", type: "spki" }), Buffer.from(sig_b64, "base64"));
}

const r = await fetch(`${SB_URL}/rest/v1/rpc/wt_hook_bundle_current`, {
  method: "POST",
  headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`, "Content-Type": "application/json",
             "Content-Profile": "wikitata", "Accept-Profile": "wikitata" },
  body: JSON.stringify({ p_caller: CALLER }),
});
if (!r.ok) { console.error(`fetch golden failed: ${r.status} ${await r.text()}`); process.exit(1); }
const bundle = await r.json();
if (!bundle.ok || !bundle.live) { console.error("no live golden bundle"); process.exit(1); }
if (!verifySig(bundle.manifest_sha256, bundle.signature)) {
  console.error("⛔ golden bundle signature INVALID — refusing to install (fail-closed)."); process.exit(2);
}

const boot = bundle.files.find((f) => f.path === BOOT_PATH);
if (!boot) { console.error(`bundle has no ${BOOT_PATH}`); process.exit(1); }
if (sha256(Buffer.from(boot.content)) !== boot.sha256) { console.error("bootstrap content hash mismatch"); process.exit(2); }

// 0) the seat identity file (ONB-FIX-5)
mkdirSync(dirname(CACP_USER), { recursive: true });
if (fileUser !== CALLER) {
  writeFileSync(CACP_USER, CALLER + "\n");
  console.log(`✓ seat identity ${CALLER} → ${CACP_USER}${fileUser ? ` (was ${fileUser})` : ""}`);
} else {
  console.log(`✓ seat identity ${CALLER} (already in ${CACP_USER})`);
}

// 1) write the bootstrap
const dst = `${CLAUDE_DIR}/${BOOT_PATH}`;
mkdirSync(dirname(dst), { recursive: true });
writeFileSync(dst, boot.content);
console.log(`✓ installed ${dst}`);

// 2) wire the SessionStart hook (idempotent, non-clobbering)
const sp = `${CLAUDE_DIR}/settings.json`;
const cfg = existsSync(sp) ? JSON.parse(readFileSync(sp, "utf8")) : {};
cfg.hooks ??= {};
cfg.hooks.SessionStart ??= [];
// absolute + forward-slash + quoted → works on Linux/macOS AND Windows (Claude Code hooks don't expand ~ on Windows)
// node by ABSOLUTE path too (task c9fc0530): the Claude desktop app starts with PATH = /etc/paths, so a bare `node`
// is not found until the app is reopened after Homebrew/Node is installed. The path comes from the bootstrap's own
// resolver (`--resolve-node`, the one instance); a bootstrap that predates the flag would run a full apply instead,
// so it is only asked when its content carries the flag — otherwise this node (process.execPath) is used.
const NODE = (() => {
  const own = process.execPath.split(String.fromCharCode(92)).join("/");
  if (!boot.content.includes("--resolve-node")) return own;
  const r = spawnSync(process.execPath, [dst, "--resolve-node"], { encoding: "utf8", timeout: 20000 });
  const p = (r.stdout || "").trim();
  return r.status === 0 && /^(\/|[A-Za-z]:\/)[^"\n]+$/.test(p) && existsSync(p) ? p : own;
})();
const CMD = `"${NODE}" "${dst.split(String.fromCharCode(92)).join("/")}"`;  // 92=backslash → forward slashes (Windows)
const already = JSON.stringify(cfg.hooks.SessionStart).includes("wt-golden-bootstrap");
if (already) {
  console.log("✓ SessionStart hook already wired — no change.");
} else {
  cfg.hooks.SessionStart.push({ hooks: [{ type: "command", command: CMD }] });
  writeFileSync(sp, JSON.stringify(cfg, null, 2));
  console.log("✓ wired SessionStart hook -> golden-bootstrap (report mode each session)");
}
// 3) two --apply passes, then the parity verdict (the seed's exit code is the seat's state)
const run = () => spawnSync(process.execPath, [dst, "--apply"], {
  encoding: "utf8", env: { ...process.env, WT_ACTOR: CALLER, WT_USER: CALLER, WT_SB_KEY: "", WT_SB_URL: "" },
});
run();
const last = run();
process.stdout.write(last.stdout || ""); process.stderr.write(last.stderr || "");
const status = ((last.stdout || "").match(/status(?: now)?=([a-z]+)/g) || []).pop()?.split("=")[1] || "unknown";
if (last.status === 0 && status === "parity") {
  console.log(`\n✅ seed installed. Golden bundle v${bundle.version} applied · status=parity · checked again at every session start.`);
  process.exit(0);
}
console.error(`\n⚠️  seed installed, but the seat is not in parity yet (status=${status}, exit ${last.status}). Finish with:\n` +
  `   WT_ACTOR=${CALLER} node ${dst.split(String.fromCharCode(92)).join("/")} --apply`);
process.exit(3);
