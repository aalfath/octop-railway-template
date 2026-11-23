# Octop for Railway: the official image plus a small start wrapper.
#
# ghcr.io/tencentcloud/octop:<version> is upstream's default ("lite") image:
# web dashboard, API, agents, cron and chat channels, without the virtual
# desktop, OCR and local-embedding extras of the ":<version>-full" tag.
# Pinned by tag and multi-arch index digest. To update: change both, read
# upstream's release notes, add a CHANGELOG.md entry, and push to main.
FROM ghcr.io/tencentcloud/octop:1.0.3b7@sha256:e80f438665c50e4ee85071628494f4ad4240c4e357c2d858e08d1423a11686ac

# HOME=/data is upstream's layout (state in ~/.octop). The Railway volume is
# mounted at /data. Numeric thread pools are capped so a small Railway plan
# isn't swamped by one thread per host CPU.
ENV HOME=/data \
    OCTOP_HOME=/data/.octop \
    OCTOP_IN_CONTAINER=1 \
    OCTOP_DEFAULT_TIMEZONE=UTC \
    OCTOP_LOG_LEVEL=info \
    LANGFUSE_TRACING_ENABLED=false \
    OMP_NUM_THREADS=2 \
    OPENBLAS_NUM_THREADS=2 \
    MKL_NUM_THREADS=2 \
    MALLOC_ARENA_MAX=2 \
    PYTHONUNBUFFERED=1 \
    PORT=8088

# bubblewrap: Octop otherwise apt-installs it in the background at every start.
# /data/.cache is upstream's build-time uv cache (about 840 MB); it isn't used
# at runtime and the volume hides it anyway.
RUN set -eu; \
    apt-get update; \
    apt-get install -y --no-install-recommends bubblewrap; \
    rm -r /var/lib/apt/lists/* /data/.cache; \
    mkdir -p /data/.octop

COPY railway/ /app/railway/

# Fail the build, not the first boot, if the wrapper or the upstream helpers
# it imports have moved.
RUN set -eu; \
    chmod 0755 /app/railway/start.sh; \
    bash -n /app/railway/start.sh; \
    python -m py_compile /app/railway/setup.py /app/railway/first_expert.py; \
    python -c "import importlib.metadata as m; v = m.version('octop'); assert v == '1.0.3b7', v"; \
    HOME=/tmp/b OCTOP_HOME=/tmp/b/.octop python -c "from octop.cli.support.db import open_cli_services; from octop.infra.agents.providers.presets import load_provider_presets; from octop.infra.users.password import validate_password_policy; assert load_provider_presets()"; \
    rm -r /tmp/b

EXPOSE 8088

ENTRYPOINT ["/app/railway/start.sh"]
CMD []
