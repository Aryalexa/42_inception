# Copilot instructions for 42_inception

## Build, test, lint
- No build, test, or lint commands are defined in the repo yet. The expected entrypoint is a root-level `Makefile` that builds images via `srcs/docker-compose.yml`.

## High-level architecture
- Docker Compose stack with three services: NGINX (TLSv1.2/1.3 only, port 443 only, single entrypoint), WordPress + php-fpm (no nginx), and MariaDB (no nginx).
- Each service runs in its own container, with image names matching service names, connected by a dedicated Docker network.
- Two named volumes persist WordPress DB data and site files, stored under `/home/<login>/data` on the host.
- Configuration and implementation are expected under `srcs/` (e.g., `docker-compose.yml`, `.env`, and `requirements/*`), with a root `Makefile` orchestrating builds.

## Key conventions and requirements
- Build images from your own Dockerfiles (one per service). Do not pull prebuilt images (base Alpine/Debian only) and do not use `latest` tags.
- Store configuration in `.env`, keep credentials out of the repo, and prefer Docker secrets for sensitive values.
- No `network: host`, `--link`, or infinite-loop entrypoints (`tail -f`, `sleep infinity`, `while true`). Containers must restart on crash.
- The WordPress admin username must not contain `admin` or `administrator`; there must be at least two DB users.
- Domain is expected to map `<login>.42.fr` to the local IP.

## Environment notes (from dev-info.md)
- **Local**: no VM required; focus on creating config files to commit, and avoid risky host changes.
- **School**: VM required, outbound internet must be configured, and SSH access to the VM is needed.
