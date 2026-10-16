# blender-mcp-docker

Headless Docker image running **Blender 5.2.2 LTS** + [mcp-for-blender](https://github.com/ahujasid/blender-mcp) (v2.1.0) — a self-waking **stdio MCP server that any MCP-capable AI agent tool can drive**. The only client requirement is the ability to spawn a stdio command; the bundled wrapper handles the `docker exec` into the container.

## Architecture

```
MCP client ──stdio──▶ docker exec -i blender-mcp mcp-for-blender
                           │ TCP localhost:9876 (container-only, zero published ports)
                           ▼
                      Xvfb :99 → Blender GUI → blender_mcp addon
                           └─ autosave timer → /work/workspace.blend every 600s
```

- **No GPU needed** — llvmpipe software GL (Xvfb + Mesa) powers the UI/screenshots; Cycles renders on CPU
- **Zero network exposure** — port 9876 only listens on container-internal localhost
- **Self-healing** — `--restart=unless-stopped` recovers from real process crashes while keeping manual stops down across host reboots; autosave restores the scene from `/work`
- **Persistent scene** — bind-mount a host dir to `/work` so image/container rebuilds never lose your project

## Build

```bash
docker build -t blender-mcp:5.2.2 .
```

## Run

```bash
mkdir -p /home/coder/blender/belend   # host dir as the Docker daemon sees it (a containerized client's /root/blender/belend may map to this)
docker run -d --name blender-mcp --restart=unless-stopped \
  --memory=3072m --memory-swap=-1 \
  -v /home/coder/blender/belend:/work \
  blender-mcp:5.2.2
docker exec blender-mcp sh -c 'grep -q ":2694" /proc/net/tcp && echo PORT_UP'   # addon up?
```

## Connect from any MCP client

Register the auto-wake wrapper as a stdio MCP server named `blender`. On every tool call it silently ensures the stack (recreates a deleted container / starts a stopped one / waits for the addon port) before exec'ing the MCP server inside the container.

Most desktop/editor clients (Claude Desktop, Cursor, Cline, VS Code, …) take an `mcpServers` JSON entry:

```json
{
  "mcpServers": {
    "blender": {
      "command": "/root/blender/blender-mcp-docker/blender-mcp-wrapper.sh",
      "args": [],
      "env": { "DISABLE_TELEMETRY": "true" }
    }
  }
}
```

CLI-style clients take the same path as the server command, e.g. `claude mcp add blender -- /root/blender/blender-mcp-docker/blender-mcp-wrapper.sh`. Transport is always stdio — no URL or port to configure; if your client exposes a `type`/`transport` field, set it to `stdio` (the default for command-based servers).

On-demand mode: `docker stop blender-mcp` when idle (manual stops survive daemon/host restarts under `unless-stopped`); the next MCP tool call wakes the whole stack automatically (~20–25 s cold).

To disable the stack entirely — so that even an MCP tool call or a client liveness probe cannot start the container — create the hard-off flag: `touch DISABLED` (both `blender-ensure.sh` and `blender-mcp-wrapper.sh` refuse to act while it exists; the wrapper exits silently so MCP clients see an immediate EOF). Remove the flag and run `blender-ensure.sh` to bring the stack back. The flag is local runtime state and is git-ignored.

## Notes

- `start.sh` auto-loads `/work/workspace.blend` if present (crash recovery)
- To change Blender version: edit the tarball URL, `ENV PATH`, and the addons dir (`~/.config/blender/<ver>/...`) — all three must match
- glibc: Debian 12 (2.36) runs Blender 5.2.2 fine (verified; the build will fail at `enable.py` step if a future Blender raises the glibc floor)
- Telemetry is off via `DISABLE_TELEMETRY=true` in the MCP client env (the addon's consent prompt stays silent on non-eliciting clients)

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | debian:12-slim + X11/GL libs + Blender 5.2.2 + uv + mcp-for-blender 2.1.0, addon pre-enabled headless |
| `enable.py` | one-shot addon enable during image build (`blender -b`) |
| `autosave.py` | bpy timer saving `/work/workspace.blend` every 600s |
| `start.sh` | Xvfb :99 → Blender GUI → addon binds 9876 (PID 1 is Blender) |
| `blender-ensure.sh` | idempotent stack ensure: recreate deleted container (unless-stopped, original flags) / start stopped / wait for 9876 |
| `blender-mcp-wrapper.sh` | MCP command wrapper: silent ensure, then `docker exec -i` mcp-for-blender (auto-wake on every tool call) |
| `mcp-probe.mjs` | full-chain protocol probe: initialize → tools/list → tools/call with stdin held open (verification) |
