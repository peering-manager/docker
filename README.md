# Docker - Peering Manager

This repository contains the components needed to build Peering Manager as a
Docker container. It provides everything that is needed to run the whole
application stack.

## Dependencies

This project relies only on *Docker* and *docker-compose*. Make sure to use a
decent version of each tool and everything will work as expected.

To check the version installed on your system run `docker --version` and
`docker-compose --version`.

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

## About

This work is based on the great
[netbox-docker](https://github.com/netbox-community/netbox-docker) project and
uses the same license.


