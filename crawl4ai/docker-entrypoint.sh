#!/bin/bash
set -e

# ── 1. Dynamic LLM Configuration ──────────────────────────────
echo "[Entrypoint] Checking LLM configuration..."

CONFIG_PY="/usr/local/lib/python3.12/site-packages/crawl4ai/config.py"

if [ -n "$LLM_PROVIDER" ]; then
    echo "[Entrypoint] LLM_PROVIDER is set to: $LLM_PROVIDER"
    if grep -q "DEFAULT_PROVIDER = \"openai/gpt-4o\"" "$CONFIG_PY"; then
        echo "[Entrypoint] Patching Default Provider..."
        sed -i "s|DEFAULT_PROVIDER = \"openai/gpt-4o\"|DEFAULT_PROVIDER = \"$LLM_PROVIDER\"|" "$CONFIG_PY"
        echo "[Entrypoint] Patch applied."
    else
        CURRENT_PROVIDER=$(grep "DEFAULT_PROVIDER =" "$CONFIG_PY" | cut -d'"' -f2)
        if [ "$CURRENT_PROVIDER" != "$LLM_PROVIDER" ]; then
             echo "[Entrypoint] Overriding $CURRENT_PROVIDER → $LLM_PROVIDER..."
             sed -i "s|DEFAULT_PROVIDER = \".*\"|DEFAULT_PROVIDER = \"$LLM_PROVIDER\"|" "$CONFIG_PY"
        else
             echo "[Entrypoint] Config already matches. No patch needed."
        fi
    fi
else
    echo "[Entrypoint] LLM_PROVIDER not set. Using default."
fi

# ── 2. Permissions ─────────────────────────────────────────────
if [ "$(id -u)" = "0" ]; then
    if [ -d "/home/appuser" ]; then
        chown -R appuser:appuser /home/appuser
    fi
    export HOME=/home/appuser
fi

# ── 3. MCP Patches (identifier + Streamable HTTP) ─────────────
echo "[Entrypoint] Checking MCP configuration..."

python3 - <<'PYEOF'
import sys, os

FILE = "/app/mcp_bridge.py"
if not os.path.exists(FILE):
    print("[MCP Patch] mcp_bridge.py not found, skipping.")
    sys.exit(0)

with open(FILE) as f:
    src = f.read()

# Skip if already fully patched
if "class ToolWithId" in src and "StreamableHTTPServerTransport" in src:
    print("[MCP Patch] Already patched.")
    sys.exit(0)

print("[MCP Patch] Applying patches...")
changed = False

# ── Patch A: ToolWithId (identifier field for LobeHub) ────────
if "class ToolWithId" not in src:
    anchor = "from mcp.server.models import InitializationOptions"
    if anchor in src:
        new_class = '''

class ToolWithId(t.Tool):
    identifier: str
'''
        src = src.replace(anchor, anchor + new_class)
        changed = True
        print("[MCP Patch] Added ToolWithId class.")

    old_inst = "t.Tool(name=k, description=desc, inputSchema=schema)"
    new_inst = "ToolWithId(name=k, identifier=k, description=desc, inputSchema=schema)"
    if old_inst in src:
        src = src.replace(old_inst, new_inst)
        changed = True
        print("[MCP Patch] Replaced Tool instantiation.")

# ── Patch B: Add Streamable HTTP transport ────────────────────
if "StreamableHTTPServerTransport" not in src:
    # Add import
    import_anchor = "from mcp.server.sse import SseServerTransport"
    new_imports = """from mcp.server.sse import SseServerTransport
from mcp.server.streamable_http import StreamableHTTPServerTransport
import anyio as _anyio"""
    if import_anchor in src:
        src = src.replace(import_anchor, new_imports)
        changed = True
        print("[MCP Patch] Added Streamable HTTP imports.")

    # Add the streamable HTTP endpoint block after SSE mount
    sse_mount = '    app.mount(f"{base}/messages", app=sse.handle_post_message)'
    streamable_block = '''    app.mount(f"{base}/messages", app=sse.handle_post_message)

    # ── Streamable HTTP transport (for LobeHub etc.) ──────────
    _streamable_path = f"{base}/streamable"

    from starlette.types import ASGIApp, Receive, Scope, Send

    class StreamableMW:
        def __init__(self, app_inner: ASGIApp):
            self.app = app_inner
        async def __call__(self, scope: Scope, receive: Receive, send: Send):
            if scope["type"] == "http" and scope["path"].rstrip("/") == _streamable_path:
                import anyio
                transport = StreamableHTTPServerTransport(
                    mcp_session_id=None,
                    is_json_response_enabled=False,
                )
                async with anyio.create_task_group() as tg:
                    async def _run():
                        async with transport.connect() as (rs, ws):
                            await mcp.run(rs, ws, mcp.create_initialization_options(), stateless=True)
                    tg.start_soon(_run)
                    await anyio.sleep(0.05)
                    await transport.handle_request(scope, receive, send)
                    await transport.terminate()
                    tg.cancel_scope.cancel()
                return
            await self.app(scope, receive, send)

    app.add_middleware(StreamableMW)'''
    if sse_mount in src:
        src = src.replace(sse_mount, streamable_block)
        changed = True
        print("[MCP Patch] Added Streamable HTTP transport at /mcp/streamable.")

if changed:
    with open(FILE, "w") as f:
        f.write(src)
    print("[MCP Patch] All patches applied successfully!")
else:
    print("[MCP Patch] No changes needed.")
PYEOF

echo "[Entrypoint] Starting Supervisord..."
exec "$@"
