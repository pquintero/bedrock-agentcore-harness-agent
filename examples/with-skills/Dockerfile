# Custom AgentCore harness environment for a Data Engineering agent.
#
# IMPORTANT: AgentCore harness images must be built for linux/arm64.
#   docker buildx build --platform linux/arm64 -t data-engineer-agent:latest .
#
# The harness overrides ENTRYPOINT/CMD and runs this image as the environment,
# so we only need the tools, dependencies, and baked-in skills on the filesystem.
FROM public.ecr.aws/docker/library/python:3.12-slim

# Common data-engineering tooling.
RUN pip install --no-cache-dir \
    pandas \
    pyarrow \
    duckdb \
    sqlglot \
    "pyspark==3.5.*"

# Bake the Agent Skills into the image at a known path. The harness `skills`
# configuration points at these directories.
COPY skills/ /app/.agents/skills/

WORKDIR /app
