# Return to Moria Dedicated Server (Docker)

This repository is a standalone, self-contained setup to build and run a **Return to Moria** dedicated server using Docker.

This is a personal project and is not affiliated with, endorsed by, or connected to any company or the game's developers.

It is functional, tested, and currently used on **Ubuntu Server 24.04 LTS**.

It is designed so you can copy only this folder into a new GitHub repository and publish the resulting image to:

- Docker Hub
- GitHub Container Registry (GHCR)

## What you get

- `Dockerfile`: builds an image based on `ghcr.io/ptero-eggs/yolks:wine_latest`
- `entrypoint.sh`: installs/updates the server via SteamCMD at runtime and starts it with Wine
- `docker-compose.yml`: runs the container with a persisted `./data` volume
- `.env.example`: configuration template

## Requirements

- Docker Engine
- Docker Compose v2 (`docker compose`)

## Quick start

From inside this folder:

1) Create your env file:

```bash
cp .env.example .env
```

1) Edit `.env` and adjust at least:

- `PUID` / `PGID`
- `WORLD_NAME`
- `SERVER_PASSWORD` (optional)

1) Build and start:

```bash
docker compose up -d --build
```

1) View logs:

```bash
docker compose logs -f
```

## Data persistence

All server files and saves are stored on the host at:

- `./data` (bind-mounted to `/mnt/server` in the container)

This means updates and server state survive container recreation.

## Network / ports

- UDP `7777` is exposed and mapped by default.

If you need different ports, update both:

- `docker-compose.yml` port mapping
- `ListenPort` / related values inside the generated `MoriaServerConfig.ini`

## Configuration (env vars)

The container reads configuration from `.env`.

### Common settings

- `WORLD_NAME`: sets `[World] Name` in `MoriaServerConfig.ini`
- `SERVER_PASSWORD`: sets `[Main] OptionalPassword`
- `DIFFICULTY`: sets `[World.Create] Difficulty.Preset`

### Steam credentials (optional)

If empty, SteamCMD uses anonymous login:

- `STEAM_USER`
- `STEAM_PASS`
- `STEAM_AUTH` (Steam Guard code if needed)

### EOS (optional)

Only set these if you know you need EOS auth. If you set any of them, you must set all required ones:

- `EOS_AUTH_TYPE`
- `EOS_AUTH_LOGIN`
- `EOS_AUTH_PASSWORD`

Optional:

- `EOS_ARTIFACT_NAME_OVERRIDE`

### Server extra args

- `SERVER_EXTRA_ARGS`: space-separated args appended to the server command.

## Troubleshooting

### First start takes time

On first run, the container will download SteamCMD and the server files into `./data`. This can take a while depending on your disk and network.

### Permission errors in `./data`

Set `PUID`/`PGID` in `.env` to match your host user:

```bash
id -u
id -g
```

Then restart:

```bash
docker compose up -d
```

### Rebuilding the image

```bash
docker compose build --no-cache
```

## Publishing images

This repository includes a GitHub Actions workflow that can publish releases to:

- Docker Hub
- GitHub Container Registry (GHCR)

The release workflow runs on `push` to `main` (and can also be run manually).

### Release flow (GitHub Actions)

The `release` workflow creates an annotated git tag automatically and pushes it to `origin`.

Versioning rules:

- Default bump is `patch`.
- Add `#minor` in the commit message to bump `minor`.
- Add `#major` in the commit message to bump `major`.

The tag format is `v<major>.<minor>.<patch>`.

The workflow also creates a GitHub Release where:

- The release title is the commit subject.
- The release body is the commit body.

### GitHub Actions configuration

Repository variables (Settings -> Secrets and variables -> Actions -> Variables):

- `DOCKERHUB_IMAGE` (required for Docker Hub publishing). Example: `mydockeruser/return-to-moria`
- `IMAGE_NAME` (optional). Defaults to `return-to-moria`
- `GHCR_IMAGE` (optional). Defaults to `ghcr.io/<owner>/<IMAGE_NAME>`

Repository secrets (Settings -> Secrets and variables -> Actions -> Secrets):

- `DOCKERHUB_USERNAME` (required for Docker Hub publishing)
- `DOCKERHUB_TOKEN` (required for Docker Hub publishing). Use a Docker Hub access token.

Notes:

- GHCR publishing uses the built-in `GITHUB_TOKEN` with `packages: write` permission.

## License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See `LICENSE`.

### Docker Hub

1) Login:

```bash
docker login
```

1) Build and tag:

```bash
docker build -t <dockerhub_user>/return-to-moria:latest .
```

1) Push:

```bash
docker push <dockerhub_user>/return-to-moria:latest
```

### GitHub Container Registry (GHCR)

1) Login:

```bash
echo <github_pat> | docker login ghcr.io -u <github_username> --password-stdin
```

1) Build and tag:

```bash
docker build -t ghcr.io/<github_username>/return-to-moria:latest .
```

1) Push:

```bash
docker push ghcr.io/<github_username>/return-to-moria:latest
```

Notes:

- Use a GitHub PAT with at least `write:packages`.
- Consider pinning versions/tags as needed for reproducible deployments.
