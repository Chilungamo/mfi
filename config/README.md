# config/

Environment and configuration space.

Runtime settings are read from environment variables (see `.env.example` at the repository
root) by `app/config.py`. Place environment-specific, non-secret configuration files here
(e.g. ingestion source registries, logging configuration). Secrets must never be committed.
