# PREREQUIRMENTS

## Required tools

- Docker Engine (`docker`)
- Docker Compose v2 plugin (`docker compose`)
- Git
- Bash shell

## Check current versions

```bash
docker --version
docker compose version
docker-compose version || true
```

## Install Docker Compose v2 (recommended user-local method)

Use this when `docker compose` is missing and `docker-compose` v1 is installed.

```bash
mkdir -p "$HOME/.docker/cli-plugins"
curl -fL "https://github.com/docker/compose/releases/download/v5.0.2/docker-compose-linux-x86_64" \
  -o "$HOME/.docker/cli-plugins/docker-compose"
chmod +x "$HOME/.docker/cli-plugins/docker-compose"
docker compose version
```

Expected output example:

```text
Docker Compose version v5.0.2
```

## Optional system-wide install (if your distro provides it)

```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
docker compose version
```

If `docker-compose-plugin` is not found, use the user-local method above.

## Notes for this repository

- Scripts are written to support both:
  - `docker compose` (preferred)
  - `docker-compose` (legacy fallback)
- Prefer `docker compose` for all new commands.
