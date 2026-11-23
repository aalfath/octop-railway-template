# Changelog

## 1.0.3b7 (2026-11-23)

First release of this template.

- Octop 1.0.3b7, `ghcr.io/tencentcloud/octop:1.0.3b7@sha256:e80f438665c50e4ee85071628494f4ad4240c4e357c2d858e08d1423a11686ac`.
- Admin created on first boot from `OCTOP_ADMIN_USERNAME` / `OCTOP_ADMIN_PASSWORD` (no setup wizard).
- Model provider from `LLM_API_KEY`, `LLM_BASE_URL`, `LLM_MODEL`; a first "General Expert" for the admin.
- SQLite database and all state on the `/data` volume.
