# blender-mcp-docker

Headless Docker image running **Blender 5.2.2 LTS** + [mcp-for-blender](https://github.com/ahujasid/blender-mcp) (v2.1.0), designed to be driven by an [OpenClaw](https://github.com/openclaw/openclaw) agent over MCP stdio — or any MCP client that can run `docker exec`.

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
- **Self-healing** — `--restart=always` recovers from real process crashes; autosave restores the scene from `/work`
- **Persistent scene** — bind-mount a host dir to `/work` so image/container rebuilds never lose your project

## Build

```bash
docker build -t blender-mcp:5.2.2 .
```

## Run

```bash
mkdir -p /home/coder/belender   # host dir; visible as /root/belender if your workspace /root is /home/coder
docker run -d --name blender-mcp --restart=always \
  --memory=3072m --memory-swap=-1 \
  -v /home/coder/belender:/work \
  blender-mcp:5.2.2
docker exec blender-mcp sh -c 'grep -q ":2694" /proc/net/tcp && echo PORT_UP'   # addon up?
```

## Connect from OpenClaw

`mcp.servers.blender`:

```json
{ "enabled": true, "command": "docker",
  "args": ["exec", "-i", "blender-mcp", "/root/.local/bin/mcp-for-blender"],
  "env": { "DISABLE_TELEMETRY": "true" },
  "transport": "stdio", "name": "blender" }
```

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
