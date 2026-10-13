---
name: remote-dev-ops
description: Use when running dev servers or commands on remote hosts.
---

# Remote Dev & Server Ops

Procedural workflow for inspecting, running services, and debugging code on remote development/lab machines via SSH.

## 1. Authentication & Non-Interactive SSH
* **Key configuration:** Automated SSH commands run non-interactively (without TTY). Password or passphrased private keys fail with `Permission denied (publickey,password)`.
* **Dedicated automation keys:** Use an unencrypted dedicated keypair (e.g. `~/.ssh/id_ed25519_agent`) appended to the remote server's `~/.ssh/authorized_keys`.
* **Persist remote host profiles:** Add convenient entries to `~/.ssh/config` (`Host`, `User`, `Port`, `IdentityFile`) to avoid repeated CLI flags and keep batch mode seamless.

## 2. Remote Shell Environment Differences (Non-login vs Login)
* Non-interactive SSH (`ssh host 'cmd'`) skips interactive shell rc files (`~/.zshrc`, `~/.bashrc` non-interactive guards). Tools installed via `nvm`, `asdf`, `gvm`, or custom user paths (`~/.nvm/versions/...`, `~/go/bin`, `~/.local/bin`) will trigger `command not found` (exit code 127).
* **Explicit loader wrap:** When running commands depending on user toolchains (Node/pnpm, Go/Air, Rust), source the environment explicitly or execute via a runner script:
  ```bash
  ssh host 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin && <command>'
  ```

## 3. Running Long-Running Dev Servers Detached
* **Do not run dev servers directly in the SSH foreground:** Commands like `pnpm run dev`, `air`, or `make dev` will hang the SSH session indefinitely until timeout.
* **Detached execution pattern:** Wrap invocation in a launcher script or invoke with `nohup` + output redirection:
  ```bash
  nohup ~/run-dev.sh > ~/dev.log 2>&1 &
  ```
* **Verify immediately:** After spawning in background, sleep 1-2 seconds and verify process tree (`ps aux | grep <pattern>`) and tail the log (`tail -n 20 dev.log`) to confirm clean startup before reporting success.

## 4. Inspecting Agent Histories & States (OMP / CLI Agents)
* Many terminal coding harnesses (e.g. OMP / Oh My Pi) maintain state in SQLite under the user's home directory (e.g. `~/.omp/agent/history.db`).
* Query sessions, prompts, and recaps directly via Python SQLite probes when the native binary is interactive or unavailable:
  * Check `session_titles` for recent session names and IDs.
  * Check `history` for prompts, timestamps, and active working directories.
