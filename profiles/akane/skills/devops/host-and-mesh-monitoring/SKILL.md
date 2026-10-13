---
name: host-and-mesh-monitoring
description: "Monitor host health, services, and Tailscale mesh peers."
version: 1.0.0
author: Akane Kurokawa
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [tailscale, monitoring, watchdog, systemctl, host-health, mesh]
    related_skills: [hermes-agent]
---

# Host and Mesh Monitoring

## When to Use
Use when inspecting host status (resources, systemd services, Docker containers) or setting up state-transition alerting for Tailscale mesh peers.

## Inspection Sequence

When evaluating host state, run low-overhead checks in order:

1. **Host resources:**
   ```bash
   uptime && free -h && df -h -x tmpfs -x devtmpfs -x squashfs
   ```
2. **Services & processes:**
   ```bash
   # Check user services first when profile-bound or non-root
   systemctl --user is-active <service> 2>/dev/null || systemctl is-active <service>
   # Top memory consumers
   ps aux --sort=-%mem | head -n 4
   ```
3. **Containers (Docker):**
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
   ```
4. **Tailscale mesh:**
   ```bash
   tailscale status
   ```

## Remote Peer Diagnostics over Tailscale (SSH)

When querying or fixing remote nodes across Tailscale mesh:
- Use non-interactive flags to avoid hanging on unresponsive peers or key prompts:
  ```bash
  ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new <user>@<tailscale-ip> "<command>"
  ```
- **Accessing Private/LAN Subnets Behind Peers:**
  When a target IP (e.g. `192.168.80.x`, `192.168.75.x`) is not advertised as a Tailscale subnet route on the VPS, pivot via an online peer on the respective local network using SSH command forwarding:
  - `gip-wrk-sandbox` (`100.93.117.28`): Directly on `192.168.80.0/24` subnet (`192.168.80.152` on `ens18`). Direct link, low latency, ideal primary jump host for that subnet.
  - `gip-wrk-aio` (`100.73.82.1`): Connected via `192.168.75.210` (`wlp2s0`), routing through gateway. Useful as secondary/fallback.
  ```bash
  ssh -o BatchMode=yes -o ConnectTimeout=5 <user>@<tailscale-peer-ip> "nc -zvw2 <lan-target-ip> <port>"
  ```
  Check banner exchange or authentication requirements before diagnosing timeouts; firewall rules or missing SSH public keys on target LAN hosts will cause banner timeouts or auth refusals.
- **Triage Full Root Filesystem (`/`):**
  Check top directory consumers excluding external mounts:
  ```bash
  du -xhd1 / 2>/dev/null | sort -h
  ```
  Common SBC/embedded Linux bloat areas on eMMC root:
  - Cache directories: `/root/.cache/*`
  - Unmounted underlays: `/mnt/*` consuming space on the root partition when secondary drives were unmounted or misconfigured.
  - Log dumps: `/var/log.hdd/` or unrotated `/var/log/*` files.

## Docker Cleanup & Prune Maintenance Pitfalls

When configuring or inspecting automated cron/maintenance scripts for Docker cleanups:
- **Avoid `-a` (`--all`) on CI/CD runner hosts:** `docker system prune -a` deletes *every* image not referenced by a currently active container. On CI/CD workers (such as GitLab Runners) where containers exit upon job completion, `-a` aggressively purges all tagged images (e.g. `:latest`, `:v*.*.*`) once they surpass the `--filter "until=..."` threshold, forcing expensive image re-pulls/re-builds.
- **Dangling vs. Unused:** Use `docker system prune -f` (without `-a`) to remove stopped containers, networks, and untagged intermediate dangling layers (`<none>`) while preserving tagged cached images.
- **Build cache:** Use `docker builder prune -f` or filter by time (`--filter "until=168h"`) specifically for BuildKit/builder cache rather than purging tagged images from local storage. Note that BuildKit cache can easily grow to 5-10GB on active build runners, so builder prune notifications often report multi-gigabyte space reclamations distinct from container image deletions.
- **SSH Automation with Non-Interactive Passwords:** When pivoting through peers using `sshpass` over nested SSH commands, set `SSH_ASKPASS_REQUIRE=never` and supply strict `-o ConnectTimeout=N` and `-o StrictHostKeyChecking=accept-new` options to prevent unattended hangs on banner exchange or host key prompts.

## Watchdog Alert Pattern (Cron `no_agent`)

For passive monitoring of remote peer connectivity, avoid recurring LLM runs. Use a zero-token `no_agent` cron watchdog script:

- Keep previous state in a scratch state file.
- Emit output strictly on state transitions (e.g. online -> offline or offline -> online).
- In `no_agent=True` mode, empty stdout suppresses delivery completely; non-empty stdout delivers directly to the target chat.

### Peer Monitor Script Pattern

```bash
#!/usr/bin/env bash
STATUS_FILE="$HOME/.hermes/profiles/$PROFILE/cache/scratch/<peer>_state.txt"
mkdir -p "$(dirname "$STATUS_FILE")"

OUTPUT=$(tailscale status 2>&1 | grep "<peer-name>" || true)

if echo "$OUTPUT" | grep -qi "offline"; then
    CURRENT="offline"
elif [ -n "$OUTPUT" ]; then
    CURRENT="online"
else
    CURRENT="unknown"
fi

PREV="online"
[ -f "$STATUS_FILE" ] && PREV=$(cat "$STATUS_FILE")
echo "$CURRENT" > "$STATUS_FILE"

# Alert on state transitions only
if [ "$CURRENT" = "offline" ] && [ "$PREV" != "offline" ]; then
    echo "⚠️ Alert: Peer \`<peer-name>\` went OFFLINE."
elif [ "$CURRENT" = "online" ] && [ "$PREV" = "offline" ]; then
    echo "✅ Notice: Peer \`<peer-name>\` is back ONLINE."
fi
```

### Schedule the Watchdog

Schedule via `cronjob_manage`:
- `schedule`: `"every 5m"`
- `no_agent`: `true`
- `deliver`: `"origin"`
- `script`: `<script-name>.sh` (under `~/.hermes/profiles/<profile>/scripts/`)
