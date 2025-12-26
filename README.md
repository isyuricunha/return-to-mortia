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

## How it works

- On the first start, the container downloads SteamCMD and the dedicated server files into `./data`.
- On subsequent starts, it can automatically update the server via SteamCMD (controlled by `AUTO_UPDATE`).
- The server is started with Wine, and uses the files located in `./data`.

This design keeps the Docker image small and keeps the game/server files persisted on the host.

## Folder layout

At a high level:

- Repository root:
  - `docker-compose.yml`, `Dockerfile`, `entrypoint.sh`
- Runtime/persistent data:
  - `./data` (bind-mounted into the container at `/mnt/server`)

After the first successful start and download, `./data` will contain the dedicated server, its configuration files, and a Wine prefix.

In other words:

- Everything in `./data` is runtime state.
- `./data` is where the dedicated server binaries live.
- `./data` is where you will edit server config, rules, and permissions.
- If you delete `./data`, the next start will re-download everything (and you will lose your local server state).

Example (your exact contents may vary depending on updates):

```text
.
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
└── data
    ├── Moria
    ├── MoriaServerConfig.ini
    ├── MoriaServerPermissions.txt
    ├── MoriaServerRules.txt
    ├── steamcmd
    ├── steamapps
    └── wineprefix
```

### What you should see after the first install

After the initial download completes, your folder will typically look similar to this (trimmed and may vary by version):

```text
.
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
└── data
    ├── Moria
    ├── MoriaServer.exe
    ├── MoriaServerConfig.ini
    ├── MoriaServerPermissions.txt
    ├── MoriaServerRules.txt
    ├── Engine
    ├── steamcmd
    ├── steamapps
    ├── wineprefix
    └── (other files like .dll/.txt manifests, redistributables, etc.)
```

If you prefer a more literal view, this is an example of what you may see after the server has been downloaded (example output; your exact files may differ):

```text
$ ls *
docker-compose.yml  Dockerfile  entrypoint.sh

data:
_CommonRedist                   Moria                       Steam              steamwebrtc64.dll  vstdlib_s.dll
DedicatedServerGuide.url        MoriaServerConfig.ini       steamapps          steamwebrtc.dll    wineprefix
Engine                          MoriaServer.exe             steamclient64.dll  tier0_s64.dll
Manifest_DebugFiles_Win64.txt   MoriaServerPermissions.txt  steamclient.dll    tier0_s.dll
Manifest_NonUFSFiles_Win64.txt  MoriaServerRules.txt        steamcmd           vstdlib_s64.dll
```

## Requirements

- Docker Engine
- Docker Compose v2 (`docker compose`)

## Prebuilt images (GHCR / Docker Hub)

If you prefer to run a prebuilt image (instead of building locally), you can pull from:

GitHub Container Registry (GHCR):

```bash
docker pull ghcr.io/isyuricunha/return-to-mortia:latest
```

Docker Hub:

```bash
docker pull isyuricunha/return-to-moria
```

Note: `latest` is the default tag on Docker Hub when you omit the tag.

This repository includes ready-to-use compose files for both registries:

- `docker-compose.ghcr.yml`
- `docker-compose.dockerhub.yml`

Example (GHCR):

```bash
cp .env.example .env
docker compose -f docker-compose.ghcr.yml up -d
```

Example (Docker Hub):

```bash
cp .env.example .env
docker compose -f docker-compose.dockerhub.yml up -d
```

## Quick start

From the repository root:

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

1) Wait for the first install to finish.

On first run, the container will download SteamCMD and the dedicated server into `./data`. This can take several minutes.

## Basic server operations

Common commands (run from the repository root):

- **Start**

```bash
docker compose up -d
```

- **Stop**

```bash
docker compose down
```

- **Logs**

```bash
docker compose logs -f
```

## Where the server actually runs from

The container runs the dedicated server binary from the persisted `./data` directory.

Inside the container, the server is expected at:

- `/mnt/server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe`

Which corresponds to this path on your host:

- `./data/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe`

## Data persistence

All server files and saves are stored on the host at:

- `./data` (bind-mounted to `/mnt/server` in the container)

This means updates and server state survive container recreation.

If you want to change server settings or rules, you will typically edit files inside `./data`.

## Network / ports

- UDP `7777` is exposed and mapped by default.

If you need different ports, update both:

- `docker-compose.yml` port mapping
- `ListenPort` / related values inside the generated `MoriaServerConfig.ini`

Note on advertise ports:

- If you need to explicitly set the server's advertise port, you can set `ADVERTISE_PORT` in `.env`.

## Configuration (env vars)

The container reads configuration from `.env`.

Important: when `WORLD_NAME`, `SERVER_PASSWORD`, or `DIFFICULTY` are set, the entrypoint updates those values in `MoriaServerConfig.ini` at startup.

If you prefer to manage `MoriaServerConfig.ini` manually, leave those env vars empty so the entrypoint does not rewrite them.

## Server configuration files (inside `./data`)

Most day-to-day server administration happens by editing files inside `./data`:

- `MoriaServerConfig.ini`
  - Main server settings (name, password, difficulty, ports).
  - The container will create a default file if it does not exist.
- `MoriaServerPermissions.txt`
  - Server permissions list (used by the dedicated server).
- `MoriaServerRules.txt`
  - Server rules (used by the dedicated server).

These files live next to the server binaries in `./data`. They are not part of the Docker image itself.

Tip: stop the container before editing to avoid confusion with auto-updates and to make sure the server reloads the settings.

### Practical editing workflow

1) Stop the server:

```bash
docker compose down
```

1) Edit the files in `./data` (for example `./data/MoriaServerConfig.ini`).

1) Start it again:

```bash
docker compose up -d
```

### Common settings

- `WORLD_NAME`: sets `[World] Name` in `MoriaServerConfig.ini`
- `SERVER_PASSWORD`: sets `[Main] OptionalPassword`
- `DIFFICULTY`: sets `[World.Create] Difficulty.Preset`

Server lifecycle / updates:

- `AUTO_UPDATE`:
  - `1` (default): update the server on every start
  - `0`: do not update on start
- `STEAM_VALIDATE`:
  - `1`: run SteamCMD `validate` (slower, but can fix broken installs)
  - `0` (default): do not validate

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

Cross-platform note:

- EOS configuration is optional.
- Even without EOS env vars configured, it is possible to play cross-platform.

### Server extra args

- `SERVER_EXTRA_ARGS`: space-separated args appended to the server command.

## Troubleshooting

### First start takes time

On first run, the container will download SteamCMD and the server files into `./data`. This can take a while depending on your disk and network.

### Editing server config / rules

The main configuration files are stored in `./data`:

- `MoriaServerConfig.ini`
- `MoriaServerPermissions.txt`
- `MoriaServerRules.txt`

Recommended flow:

1) Stop the container.
1) Edit the files.
1) Start the container again.

This reduces the chance of config being overwritten while the server is running.

### Forcing an update / repair

The server is updated via SteamCMD.

- To force an update on next start, keep `AUTO_UPDATE=1` and restart the container.
- If you suspect a broken install, set `STEAM_VALIDATE=1` and restart (this is slower).

After the server starts successfully again, you can set `STEAM_VALIDATE` back to `0`.

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

## Backups

Everything you need to back up is in `./data`.

Recommended approach:

1) Stop the container:

```bash
docker compose down
```

1) Backup the folder:

```bash
tar -czf return-to-moria-backup.tar.gz data
```

1) Start the container again:

```bash
docker compose up -d
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
