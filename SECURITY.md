# Security policy

**English** · [繁體中文](SECURITY.zh-TW.md) · [简体中文](SECURITY.zh-CN.md)

## Reporting a vulnerability

Report privately through GitHub's advisory form rather than opening a public issue:

**<https://github.com/rickw00d/LLM-Explorer/security/advisories/new>**

Please include what an attacker can reach, the steps to reproduce, and the commit you
tested. Never attach a token, a `.env`, or anything from `Secret/`.

This is a personal project, not a product with an on-call rotation. Expect a reply
within a week or so.

Only the `main` branch is supported. There are no releases to back-port to.

## What this software exposes

Read this before putting the box on a network you do not control. The three services
have different postures, and one of them is reachable from the LAN by default.

| Service | Port | Binds to | Authentication |
|---|---|---|---|
| Open WebUI + Ollama | 8080 | `127.0.0.1` | its own account system |
| ComfyUI | 8188 | `127.0.0.1` | **none at all** |
| Comparison tool | 8890 | **`0.0.0.0`** (all interfaces) | none, unless a token is set |

Two consequences worth stating plainly:

- **ComfyUI has no authentication.** Anyone who reaches port 8188 can queue arbitrary
  workflows, which means reading and writing files anywhere the ComfyUI process can.
  It is bound to loopback for exactly this reason. Do not expose it.
- **The comparison tool binds every interface.** Out of the box, any device on the same
  network can open it, and in local mode there is nothing to stop them queueing work on
  your ComfyUI through it. Set `COMPARE_HOST=127.0.0.1` to restrict it to this machine,
  or set a token.

## Public mode

Setting `COMPARE_TOKEN` (or creating `compare/.token`) switches the comparison server
into public mode:

1. Every `/api/*` call must carry a matching `X-Compare-Token` header. The comparison
   is constant-time.
2. The administrative endpoints — `/api/import`, `/api/savewf`, `/api/capture`,
   `/api/uitpl` — are blocked. They write files or push arbitrary workflows into
   ComfyUI, which is read/write access to the machine. `COMPARE_ADMIN=1` re-enables
   them; only do that on a trusted network.
3. A resolution allow-list, a queue cap, a model-count cap and a prompt-length cap
   apply.

`/api/stop` is deliberately *not* an admin endpoint: cancelling your own run is not a
write primitive, and the remote UI needs it.

### The tunnel interlock

`compare/tunnel.sh` refuses to open a Cloudflare tunnel unless an unauthenticated
request to the server returns 401. That check exists so a tunnel cannot be opened to a
server running without a token. Please do not remove it.

```bash
openssl rand -hex 32 > compare/.token   # never commit this
cd compare && ./start.sh                # picks the token up automatically
./tunnel.sh start
```

## Hardening checklist

- [ ] `COMPARE_HOST=127.0.0.1` if you do not need LAN access
- [ ] A token in `compare/.token` if you do
- [ ] `COMPARE_ADMIN` unset in public mode
- [ ] ComfyUI left on loopback, with no `--listen`
- [ ] Port 8188 firewalled off from the LAN
- [ ] `compare/.token`, `compare/.env` and `Secret/` untracked — all three are in
      `.gitignore`; `git status --porcelain --ignored` will confirm

## Out of scope

These are known and intended, not vulnerabilities:

- ComfyUI shipping without authentication. That is upstream's design; this repository
  responds by binding it to loopback.
- Anything reachable only because you deliberately changed a bind address, opened a
  firewall port, or set `COMPARE_ADMIN=1`.
- Weights downloaded from HuggingFace. Trust in a model repository is yours to decide;
  `download-models.sh` fetches `.safetensors`, which does not execute code on load,
  but a malicious workflow still can.
