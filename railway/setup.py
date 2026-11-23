"""Railway boot step: admin locale (first boot) and the LLM provider from variables."""

from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path


def log(msg: str) -> None:
    print(f"[railway] {msg}", flush=True)


def main() -> int:
    from octop.cli.support.db import open_cli_services
    from octop.infra.agents.providers.presets import load_provider_presets

    home = Path(os.environ.get("OCTOP_HOME") or Path.home() / ".octop")
    first_boot = (home / ".railway-first-boot").exists()
    username = os.environ.get("OCTOP_ADMIN_USERNAME") or "admin"
    locale = "zh" if (os.environ.get("OCTOP_ADMIN_LOCALE") or "en").lower().startswith("zh") else "en"

    api_key = (os.environ.get("LLM_API_KEY") or "").strip()
    base_url = (os.environ.get("LLM_BASE_URL") or "https://api.openai.com/v1").strip().rstrip("/")
    model = (os.environ.get("LLM_MODEL") or "").strip()
    stamp_file = home / ".railway-llm"
    stamp = hashlib.sha256(json.dumps([api_key, base_url, model]).encode()).hexdigest()

    with open_cli_services() as svc:
        if first_boot:
            row = svc.user_repo.get_by_username(username)
            if row is not None and row.locale != locale:
                svc.user_repo.set_locale(row.id, locale)
                log(f"admin '{username}' UI language set to {locale}")

        if not api_key:
            log("LLM_API_KEY is empty: add a model provider in Settings > Models")
            return 0
        if stamp_file.exists() and stamp_file.read_text().strip() == stamp:
            return 0
        if not model:
            log("LLM_MODEL is empty: provider not changed")
            return 0

        # Reuse upstream's preset (name, protocol, model metadata) when the base
        # URL is a known provider; otherwise add a generic OpenAI-compatible one.
        preset = next(
            (p for p in load_provider_presets()
             if (p.get("base_url") or "").rstrip("/") == base_url and p.get("purpose", "chat") == "chat"),
            None,
        )
        name = preset["name"] if preset else "LLM"
        kind = (preset or {}).get("protocol") or "openai"
        entry = next((dict(m) for m in (preset or {}).get("models", []) if m.get("id") == model),
                     {"id": model, "name": model})
        entry["enabled"] = True

        repo = svc.provider_repo
        row = repo.get_by_name(name)
        if row is None:
            repo.create(name=name, kind=kind, base_url=base_url, api_key=api_key,
                        models_json=json.dumps([entry]))
            log(f"added model provider '{name}' ({base_url}) with model {model}")
        else:
            models = [m for m in row.get_models() if m.get("id") != model]
            repo.update(row.id, kind=kind, base_url=base_url, api_key=api_key,
                        models_json=json.dumps([entry, *models]), enabled=True)
            log(f"updated model provider '{name}' ({base_url}), model {model}")
        svc.settings_repo.set_active_model(name, model)

    stamp_file.write_text(stamp + "\n")
    stamp_file.chmod(0o600)
    return 0


if __name__ == "__main__":
    sys.exit(main())
