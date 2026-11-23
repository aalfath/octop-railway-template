"""First boot only: wait for Octop, then give the admin a first expert (agent).

Upstream's setup wizard does this; the Docker bootstrap doesn't, which leaves a
new install with an empty chat page. Uses the bundled "default" (General Expert)
template, so no market download is needed. Never fatal.
"""

from __future__ import annotations

import json
import os
import time
import urllib.request
from pathlib import Path

base = f"http://127.0.0.1:{os.environ.get('PORT', '8088')}"
home = Path(os.environ.get("OCTOP_HOME") or Path.home() / ".octop")
marker = home / ".railway-first-boot"


def call(method: str, path: str, body: object = None, token: str | None = None) -> object:
    headers = {"content-type": "application/json"}
    if token:
        headers["authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read() or b"null")


def main() -> None:
    for _ in range(150):
        try:
            if call("GET", "/api/health").get("ok"):
                break
        except Exception:
            pass
        time.sleep(2)
    else:
        print("[railway] first expert: Octop did not answer; skipped", flush=True)
        return
    login = call("POST", "/api/auth/login", {
        "username": os.environ.get("OCTOP_ADMIN_USERNAME") or "admin",
        "password": os.environ.get("OCTOP_ADMIN_PASSWORD") or "",
    })
    token = login["access_token"]
    if not call("GET", "/api/agents", token=token):
        agent = call("POST", "/api/agents/from-expert/default", {}, token=token)
        print(f"[railway] first expert created: {agent.get('name')} ({agent.get('agent_id')})", flush=True)
    marker.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # never take the app down
        print(f"[railway] first expert: skipped ({type(exc).__name__}: {exc})", flush=True)
