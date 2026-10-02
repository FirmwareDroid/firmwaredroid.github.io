---
title: Getting Started
author: tom
date: 2025-08-27 13:37:00 +0800
last_modified_at: 2026-10-02 08:45:00 +0200
description: Install, start, configure, and verify FirmwareDroid using Docker Compose with zero manual configuration.
categories: [Setup, Tutorial]
tags: [installation, getting started, docker]
order: 1
position: 1
group: start
icon: fas fa-rocket
label: Setup
featured: true
---

FirmwareDroid (FMD) supports zero-configuration startup out of the box with Docker Compose. Manual setup scripts and
pre-generated environment files are no longer required: an automated bootstrap container (`fmd-init`) creates all
required certificates, credentials, and service configurations on the first start.

The recommended deployment path uses the published images from the GitHub Container Registry. Developers who need to
modify FMD can build and run directly from source instead.

> FMD is a research prototype and is not intended to be exposed directly to the public Internet. The default setup
> uses self-signed certificates and development-oriented settings.
{: .prompt-warning }

## Quickstart (Automatic Requirement Check & Setup)

Run the automated installer script to check all system prerequisites, clone the repository, launch the stack, and display generated credentials:

```bash
curl -fsSL https://firmwaredroid.github.io/install.sh | bash
```

The script verifies:
1. **Operating System & Architecture**: Linux or macOS (including Rosetta instructions for Apple Silicon).
2. **Core CLI Tools**: Git and cURL availability.
3. **Docker Engine & Compose V2**: Active Docker daemon and `docker compose` plugin support.
4. **Port Availability**: Checks that ports `80`, `443`, `27017`, and `7474` are free from conflicts.
5. **Disk Space**: Ensures at least 15 GB of storage space is available.

---

## Prerequisites

Install the following tools on the host:

- Git (including submodule support if building or modifying the web frontend from source).
- Docker Engine with the Docker Compose v2 plugin (`docker compose`), or a current Docker Desktop installation.
- Enough free disk space for Docker images, firmware archives, extracted files, and database storage.

The supplied Docker configuration targets `linux/amd64`. Docker Desktop can run it through emulation on Apple Silicon,
but image builds and analysis jobs will usually be slower than on a native AMD64 Linux host.

The default deployment binds ports:
- `80` (HTTP reverse proxy)
- `443` (HTTPS web client and API)
- `27017` (MongoDB replica set)
- `7474`, `7473`, `7687`, and `7688` (Neo4j browser and Bolt interface)

Confirm that Docker and Compose are available:

```bash
docker --version
docker compose version
```

## 1. Download FMD

Clone the repository:

```bash
git clone https://github.com/FirmwareDroid/FirmwareDroid.git
cd FirmwareDroid
```

If you plan to build or modify the frontend from source, initialize submodules:

```bash
git submodule update --init --recursive
```

## 2. Start FMD

Choose one deployment method. FMD works immediately without running any pre-configuration scripts.

### Option A: Published release images (recommended)

Pull and start the official image bundle:

```bash
docker compose -f docker-compose-release.yml up -d
```

Optionally pull images beforehand:

```bash
docker compose -f docker-compose-release.yml pull
docker compose -f docker-compose-release.yml up -d
```

The release compose file starts the backend, Nginx, MongoDB, Redis, Neo4j, the firmware extractor worker, and the APK
scanner worker.

For reproducible research environments, replace the `latest` image tags in `docker-compose-release.yml` with specific
version tags from the same release.

### Option B: Build and run from source

To run directly from source code:

```bash
docker compose up -d
```

Docker Compose will build any missing local images (init, backend, Nginx, extractor, and scanner) automatically before
starting the services.

Developers who want to build, tag, and scan all images explicitly can use the build script:

```bash
./docker/build_images.sh
docker compose up -d
```

## 3. Retrieve Generated Credentials

On the initial run, the `init` container (`fmd-init`) automatically generates self-signed TLS certificates, MongoDB
replica set credentials, Redis configuration, and Django administrator secrets into an isolated Docker volume
(`fmd-config`). No credentials or certificates are written to the host repository.

View the generated administrator credentials in the `init` container logs:

```bash
# When using docker-compose.yml:
docker compose logs init

# When using docker-compose-release.yml:
docker compose -f docker-compose-release.yml logs init
```

Alternatively, copy the generated credentials file to your current working directory:

```bash
# When using docker-compose.yml:
docker compose cp init:/config/secrets/generated-secrets.txt .

# When using docker-compose-release.yml:
docker compose -f docker-compose-release.yml cp init:/config/secrets/generated-secrets.txt .
```

Display the credentials:

```bash
cat generated-secrets.txt
```

## 4. Verify the Deployment

List the running services and follow their startup logs:

```bash
# When using docker-compose.yml:
docker compose ps
docker compose logs -f

# When using docker-compose-release.yml:
docker compose -f docker-compose-release.yml ps
docker compose -f docker-compose-release.yml logs -f
```

During the first start, `fmd-init` completes first with exit status `0` (`service_completed_successfully`). Once
initialization finishes, the remaining services start up. A healthy deployment contains the following services:

- `fmd-init` (`init`): Bootstrap container (exited after successful initialization)
- `backend-worker` (`web`): Django GraphQL API and application backend
- `mongo-db-1`: MongoDB replica set with keyfile authentication
- `redis`: Task queue broker
- `neo4j`: Graph database
- `extractor-worker-1`: RQ worker for firmware unpacking and extraction
- `apk_scanner-worker-1`: RQ worker for static APK analysis
- `nginx`: Reverse proxy with TLS termination and static file server

If a service exits or needs inspection, view its logs directly:

```bash
docker compose logs SERVICE_NAME
# or:
docker compose -f docker-compose-release.yml logs SERVICE_NAME
```

## 5. Optional Configuration and Overrides

FirmwareDroid requires no `.env` file by default. If you wish to customize runtime parameters, you can optionally create
a `.env` file in the repository root. Docker Compose automatically loads variables from `.env` if the file exists.

Common customization options include:

- `DOMAIN_NAME`: Domain name used for TLS certificates and Nginx routing (default: `fmd.localhost`).
- `DOCKER_CPU_LIMIT`, `DOCKER_MEMORY_LIMIT`: Resource limits for workers (defaults: `0.5` CPU, `10GB` memory).
- `LOCAL_STORAGE_PATH_00` through `LOCAL_STORAGE_PATH_09`: Host paths mapped to file storage partitions (default: `./blob_storage/00_file_storage` to `./blob_storage/09_file_storage`).
- `LOCAL_MONGO_DB_PATH_NODE1`: Host path for MongoDB data (default: `./blob_storage/mongo_database`).
- `LOCAL_NEO4J_DB_PATH`: Host path for Neo4j data (default: `./blob_storage/neo4j_database`).

> Modifying `.env` after the initial run does not alter certificates or credentials already generated in the
> `fmd-config` volume. To regenerate credentials with a new configuration, tear down volumes with
> `docker compose down -v` and restart.
{: .prompt-info }

## 6. Sign In and Explore FMD

Open [https://fmd.localhost/](https://fmd.localhost/) in your browser. Because the local deployment uses self-signed
certificates, your browser will display a TLS warning. Accept the certificate to proceed.

Log in using the administrator credentials retrieved in Step 3.

Primary endpoints:

- [Web client](https://fmd.localhost/): Main user interface
- [GraphQL API and explorer](https://fmd.localhost/graphql/): Interactive GraphQL API console
- [Django administration](https://fmd.localhost/admin/): System and user administration
- [RQ job management](https://fmd.localhost/django-rq/): Background job queues monitor
- [Neo4j browser](http://localhost:7474/): Neo4j graph database interface (or HTTPS at `https://localhost:7473/`)

Continue with [Exploring the API]({{ '/posts/exploring-the-api/' | relative_url }}) to import firmware images, monitor
extraction jobs, schedule APK analysis, and query results.

## Routine Operations

### Stop FMD

Stop all services while preserving database data and generated secrets:

```bash
# When using docker-compose.yml:
docker compose down

# When using docker-compose-release.yml:
docker compose -f docker-compose-release.yml down
```

### Restart FMD

Restart the existing deployment:

```bash
# When using docker-compose.yml:
docker compose up -d

# When using docker-compose-release.yml:
docker compose -f docker-compose-release.yml up -d
```

### Reset State and Regenerate Credentials

To reset the deployment completely and generate new certificates and passwords:

```bash
docker compose down -v
# or:
docker compose -f docker-compose-release.yml down -v
```

> Passing `-v` destroys the `fmd-config` volume and any persistent container volumes, deleting all existing
> credentials and database state.
{: .prompt-danger }

### Update FMD

To update a deployment using published release images:

```bash
git pull
docker compose -f docker-compose-release.yml pull
docker compose -f docker-compose-release.yml up -d
```
