# Docker - Peering Manager

This repository contains the components needed to build Peering Manager as a
Docker container. It provides everything that is needed to run the whole
application stack.

## Dependencies

This project relies only on *Docker* and *docker-compose*. Make sure to use a
decent version of each tool and everything will work as expected.

To check the version installed on your system run `docker --version` and
`docker compose --version`.

## Getting Started

### Built Images

Official Docker images of Peering Manager are available on
[Docker Hub](https://hub.docker.com/r/peeringmanager/peering-manager)

### Building Images

To build your own images you'll need the following binary: `bash`, `curl`,
`git` and `jq` (in addition to Docker and standard UNIX utils).

`./build.sh` can be used to rebuild Docker images. See `./build.sh --help` for
more information. `build-latest.sh` will automatically retrieve the last
available version of Peering Manager and build its image.

### Running With Docker Compose

To run the Peering Manager application stack with Docker Compose, copy the
`docker-compose.override.yml.example` file into `docker-compose.override.yml`
and override definitions from this file.

### Scheduled Tasks

Peering Manager 1.11 and later run housekeeping and PeeringDB synchronisation
from the `rqworker` service. Manage the schedule of each task from
**Admin > Scheduled Tasks** in the web interface.

The `housekeeping` and `peeringdb-sync` services stay in `docker-compose.yml`
for users who prefer an external scheduler. They do not start by default.
First disable the matching tasks in **Admin > Scheduled Tasks**, then start
them:

```shell
docker compose --profile external-scheduler up --detach
```

Do not run a task twice. Two runs of the same task waste resources, and a
PeeringDB synchronisation can take about 90 minutes.

### Base Path

Set `BASE_PATH` in `env/peering-manager.env` to serve Peering Manager from a
directory, for example `https://example.com/peering/`:

```shell
BASE_PATH=peering/
```

The container applies the value to the URLs, to the static files and to its
health check.

## About

This work is based on the great
[netbox-docker](https://github.com/netbox-community/netbox-docker) project and
uses the same license.
