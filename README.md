# <img src="img/wildIntel_logo.webp" alt="Wildintel Tools Logo" height="60"> wildintel-frontend

![Docker](https://img.shields.io/badge/docker-required-blue.svg)
![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
[![WildINTEL](https://img.shields.io/badge/WildINTEL-v1.0-blue)](https://wildintel.eu/)
[![Trapper](https://img.shields.io/badge/Trapper-Frontend-green)](https://gitlab.com/trapper-project/trapper)

<hr>

## WildIntel Trapper frontend deployment

This repository contains the configuration required to deploy `trapper-frontend` with Docker Compose, Caddy, and Traefik.

The main workflow is automated in `setup.sh`, which:

- loads variables from `.env` if present,
- validates the basic configuration,
- selects the Caddy profile (`prod` or `debug`),
- assembles the required Docker files,
- and starts, stops, or inspects the service.

## 🚀 What this repository does

- Deploys the static Trapper frontend behind Traefik.
- Lets you use an already published image or build one locally.
- Mounts a different `Caddyfile` depending on the selected profile.
- Scales the `app` service to multiple instances with Docker Compose.
- Exposes simple operational commands through `./setup.sh`.

## 📋 Requirements

- Docker
- Docker Compose plugin (`docker compose`)
- Bash
- Access to the external Docker network used by Traefik

### Important network requirement

This deployment expects an external Docker network for Traefik. By default:

- `TRAEFIK_NETWORK=wildintel-proxy`

If that network does not exist on your machine, create it before starting the service:

```bash
docker network create wildintel-proxy
```

If your environment uses a different network, change it in `.env`.

## 🧭 Relevant structure

- `setup.sh`: main deployment and operations script.
- `example.env`: environment variable template.
- `docker/docker-compose.base.yml`: base definition for the `app` service.
- `docker/docker-compose.traefik.yml`: Traefik labels and network settings.
- `docker/docker-compose.caddy-prod.yml`: mounts `caddy/Caddyfile.prod`.
- `docker/docker-compose.caddy-debug.yml`: mounts `caddy/Caddyfile.debug`.
- `docker/Dockerfile`: final Caddy-based image that serves the frontend build.

## 💻 Installation

Clone the repository:

```bash
git clone https://github.com/ijfvianauhu/wildintel-frontend.git
cd wildintel-frontend
```

Create your configuration file from the example:

```bash
cp example.env .env
```

Edit `.env` with the values for your environment before starting the service.

## ⚙️ Configuration

`setup.sh` automatically loads the `.env` file if it exists.

### Main variables

| Variable | Required | Description | Default value |
|---|---|---|---|
| `TRAPPER_BACKEND_URL` | Yes | Base URL of the Trapper backend API | `https://wildintel-trap.uhu.es` |
| `TRAPPERCS_DOMAIN` | Recommended | Domain that Traefik will use to route the frontend | `wildintel-cs.uhu.es` |
| `COMPOSE_PROJECT_NAME` | No | Docker Compose project name | `trapper-frontend` |
| `BUILD_IMAGES` | No | `1` to build the image locally, `0` to use a remote image | `0` |
| `APP_NAME` | No | Path of the compiled app inside `dist/apps/` | `trapper-frontend-cs` |
| `DOCKERFILE` | No | Path to the Dockerfile used for the build | `docker/Dockerfile` |
| `INSTANCES` | No | Number of `app` service instances | `3` |
| `CADDY_LOG_LEVEL` | No | Caddy log level | `INFO` |
| `CADDY_PROFILE` | No | Caddy configuration profile: `prod` or `debug` | `prod` |
| `TRAEFIK_NETWORK` | No | Name of the external network used by Traefik | `wildintel-proxy` |
| `TLS_ENABLED` | No | Enables or disables TLS in the Traefik router | `true` |

### Caddy profiles

The script only accepts these values for `CADDY_PROFILE`:

- `prod`: uses `caddy/Caddyfile.prod`
- `debug`: uses `caddy/Caddyfile.debug`

If any other value is used, `setup.sh` exits with an error.

### Image selection

Behavior depends on `BUILD_IMAGES`:

- `BUILD_IMAGES=0`: pulls the image `registry.gitlab.com/trapper-project/trapper-frontend:main`
- `BUILD_IMAGES=1`: builds the frontend locally and creates an image tagged as `local`

When building locally, the script runs these commands inside a Node container:

- `npm install`
- `npm run build`

It then creates the final image using `docker/Dockerfile`.

> Note: for `BUILD_IMAGES=1` to work, the frontend source code and its `npm` configuration must be present and buildable in this repository.

## 🛠️ Usage

All commands must be executed from the project root.

### Start in detached mode

```bash
./setup.sh start
```

This command:

1. loads `.env`,
2. validates `TRAPPER_BACKEND_URL`,
3. selects the `base`, `traefik`, and `caddy-<profile>` compose files,
4. pulls or builds the image,
5. and starts the service in detached mode.

### Start in interactive mode

```bash
./setup.sh start-i
```

Useful for debugging or for seeing logs directly in the terminal.

### View logs

```bash
./setup.sh logs
```

### Open a shell inside the service

```bash
./setup.sh shell
```

### Stop the deployment

```bash
./setup.sh stop
```

## 🧪 Docker composition used by the script

Internally, `setup.sh` always includes:

- `docker/docker-compose.base.yml`
- `docker/docker-compose.traefik.yml`

It then adds one of these depending on the selected profile:

- `docker/docker-compose.caddy-prod.yml`
- `docker/docker-compose.caddy-debug.yml`

When starting the service, it also scales it with:

- `--scale app=${INSTANCES}`

## 🔎 Runtime behavior

### Health check

The service defines an internal HTTP health check on:

- `http://127.0.0.1/readyz`

Traefik also uses `/readyz` to check service health.

### Exposed service

Traefik routes traffic to the internal port:

- `80`

The routing rule is built with:

- `Host(\`${TRAPPERCS_DOMAIN}\`)`

## ✅ Recommended minimal deployment

1. Copy `example.env` to `.env`.
2. Adjust at least `TRAPPER_BACKEND_URL` and `TRAPPERCS_DOMAIN`.
3. Make sure the `TRAEFIK_NETWORK` network exists.
4. Start the service with `./setup.sh start`.
5. Review logs with `./setup.sh logs` if something does not respond as expected.

## ⚠️ Notes and limitations

- `setup.sh` requires `TRAPPER_BACKEND_URL` to have a value.
- The Caddy profile can only be `prod` or `debug`.
- The Traefik network is marked as `external: true`, so it is not created automatically.
- If you use `BUILD_IMAGES=0`, you depend on the remote image being available and accessible.
- If you use `BUILD_IMAGES=1`, you depend on the frontend being able to build locally with `npm install` and `npm run build`.

## 🤝 Contributing

Contributions are welcome. If you change the deployment workflow, update `setup.sh`, `example.env`, and this `README.md` as well so they stay in sync.

## 📝 License

This project is licensed under the GNU General Public License v3.0 or later. See [`LICENSE`](LICENSE) for details.

## 🏛️ Funding

This work is part of the [WildINTEL project](https://wildintel.eu/), funded by the Biodiversa+ Joint Research Call 2022-2023 “Improved transnational monitoring of biodiversity and ecosystem change for science and society (BiodivMon)”. Biodiversa+ is the European co-funded biodiversity partnership supporting excellent research on biodiversity with an impact for policy and society. Biodiversa+ is part of the European Biodiversity Strategy for 2030 that aims to put Europe’s biodiversity on a path to recovery by 2030 and is co-funded by the European Commission.
