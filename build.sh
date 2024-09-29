#!/bin/bash
# Clones the Peering Manager repository from Github and builds the Dockerfile

source ./build-functions/gh-functions.sh

echo "▶️ $0 $*"

set -e

if [ "${1}x" == "x" ] || [ "${1}" == "--help" ] || [ "${1}" == "-h" ]; then
  _BOLD=$(tput bold)
  _GREEN=$(tput setaf 2)
  _CYAN=$(tput setaf 6)
  _CLEAR=$(tput sgr0)

  cat <<END_OF_HELP
${_BOLD}Usage:${_CLEAR} ${0} <branch> [--push]

branch       The branch or tag to build. Required.
--push       Pushes the built container image to the registry.

${_BOLD}You can use the following ENV variables to customize the build:${_CLEAR}

SRC_ORG     Which fork of Peering Manager to use (i.e. github.com/\${SRC_ORG}/\${SRC_REPO}).
            ${_GREEN}Default:${_CLEAR} peering-manager
            
SRC_REPO    The name of the repository to use (i.e. github.com/\${SRC_ORG}/\${SRC_REPO}).
            ${_GREEN}Default:${_CLEAR} peering-manager
            
URL         Where to fetch the code from.
            Must be a git repository. Can be private.
            ${_GREEN}Default:${_CLEAR} https://github.com/\${SRC_ORG}/\${SRC_REPO}.git

PEERING_MANAGER_PATH The path where Peering Manager will be checkout out.
            Must not be outside of the docker repository (because of Docker)!
            ${_GREEN}Default:${_CLEAR} .peering-manager

SKIP_GIT    If defined, git is not invoked and \${PEERING_MANAGER_PATH} will not be altered.
            This may be useful, if you are manually managing the PEERING_MANAGER_PATH.
            ${_GREEN}Default:${_CLEAR} undefined

TAG         The version part of the image tag.
            ${_GREEN}Default:${_CLEAR}
              When <branch>=master:  latest
              When <branch>=develop: snapshot
              Else:                  same as <branch>

IMAGE_NAMES The names used for the image including the registry
            Used for tagging the image.
            ${_GREEN}Default:${_CLEAR} docker.io/peeringmanager/peering-manager
            ${_CYAN}Example:${_CLEAR} 'docker.io/peeringmanager/peering-manager ghcr.io/peering-manager/peering-manager'

DOCKER_TAG  The name of the tag which is applied to the image.
            Useful for pushing into another registry than hub.docker.com.
            ${_GREEN}Default:${_CLEAR} \${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}:\${TAG}

DOCKER_SHORT_TAG The name of the short tag which is applied to the
            image. This is used to tag all patch releases to their
            containing version e.g. v2.5.1 -> v2.5
            ${_GREEN}Default:${_CLEAR} \${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}:<MAJOR>.<MINOR>

DOCKERFILE  The name of Dockerfile to use.
            ${_GREEN}Default:${_CLEAR} Dockerfile

BUILDX_PLATFORMS
            Specifies the platform(s) to build the image for.
            ${_CYAN}Example:${_CLEAR} 'linux/amd64,linux/arm64'
            ${_GREEN}Default:${_CLEAR} 'linux/amd64'

BUILDX_BUILDER_NAME
            If defined, the image build will be assigned to the given builder.
            If you specify this variable, make sure that the builder exists.
            If this value is not defined, a new builx builder with the directory name of the
            current directory (i.e. '$(basename "${PWD}")') is created."
            ${_CYAN}Example:${_CLEAR} 'clever_lovelace'
            ${_GREEN}Default:${_CLEAR} undefined

BUILDX_REMOVE_BUILDER
            If defined (and only if BUILDX_BUILDER_NAME is undefined),
            then the buildx builder created by this script will be removed after use.
            This is useful if you build Peering Manager Docker on an automated system that
            does not manage the builders for you.
            ${_CYAN}Example:${_CLEAR} 'on'
            ${_GREEN}Default:${_CLEAR} undefined

HTTP_PROXY  The proxy to use for http requests.
            ${_CYAN}Example:${_CLEAR} http://proxy.domain.tld:3128
            ${_GREEN}Default:${_CLEAR} undefined

NO_PROXY    Comma-separated list of domain extensions proxy should not be used for.
            ${_CYAN}Example:${_CLEAR} .domain1.tld,.domain2.tld
            ${_GREEN}Default:${_CLEAR} undefined

DEBUG       If defined, the script does not stop when certain checks are unsatisfied.
            ${_GREEN}Default:${_CLEAR} undefined

DRY_RUN     Prints all build statements instead of running them.
            ${_GREEN}Default:${_CLEAR} undefined
            
GH_ACTION   If defined, special 'echo' statements are enabled that set the
            following environment variables in Github Actions:
            - FINAL_DOCKER_TAG: The final value of the DOCKER_TAG env variable
            ${_GREEN}Default:${_CLEAR} undefined

CHECK_ONLY  Only checks if the build is needed and sets the GH Action output.

${_BOLD}Examples:${_CLEAR}

${0} main
            This will fetch the latest 'main' branch, build a Docker Image and tag it
            'peeringmanager/peering-manager:snapshot'.

${0} v1.8.3
            This will fetch the 'v1.8.3' tag, build a Docker Image and tag it
            'peeringmanager/peering-manager:v1.8.3' and 'peeringmanager/peering-manager:v1.8'.

${0} develop-1.9
            This will fetch the 'develop-1.9' branch, build a Docker Image and tag it
            'peeringmanager/peering-manager:develop-1.9'.

SRC_ORG=gmazoyer ${0} feature-x
            This will fetch the 'feature-x' branch from https://github.com/gmazoyer/peering-manager.git,
            build a Docker Image and tag it 'peeringmanager/peering-manager:feature-x'.

SRC_ORG=gmazoyer DOCKER_ORG=gmazoyer ${0} feature-x
            This will fetch the 'feature-x' branch from https://github.com/gmazoyer/peering-manager.git,
            build a Docker Image and tag it 'gmazoyer/peering-manager:feature-x'.
END_OF_HELP

  if [ "${1}x" == "x" ]; then
    exit 1
  else
    exit 0
  fi
fi

# Check if we have everything needed for the build
source ./build-functions/check-commands.sh
# Load all build functions
source ./build-functions/get-public-image-config.sh
source ./build-functions/gh-functions.sh

IMAGE_NAMES="${IMAGE_NAMES-docker.io/peeringmanager/peering-manager}"
IFS=' ' read -ra IMAGE_NAMES <<<"${IMAGE_NAMES}"

###
# Enabling dry-run mode
###
if [ -z "${DRY_RUN}" ]; then
  DRY=""
else
  echo "⚠️ DRY_RUN MODE ON ⚠️"
  DRY="echo"
fi

gh_echo "::group::⤵️ Fetching the Peering Manager source code"

###
# Variables for fetching the source
###
SRC_ORG="${SRC_ORG-peering-manager}"
SRC_REPO="${SRC_REPO-peering-manager}"
PEERING_MANAGER_BRANCH="${1}"
URL="${URL-https://github.com/${SRC_ORG}/${SRC_REPO}.git}"
PEERING_MANAGER_PATH="${PEERING_MANAGER_PATH-.peering-manager}"

###
# Fetching the source
###
if [ "${2}" != "--push-only" ] && [ -z "${SKIP_GIT}" ] ; then
  REMOTE_EXISTS=$(git ls-remote --heads --tags "${URL}" "${PEERING_MANAGER_BRANCH}" | wc -l)
  if [ "${REMOTE_EXISTS}" == "0" ]; then
    echo "❌ Remote branch '${PEERING_MANAGER_BRANCH}' not found in '${URL}'; Nothing to do"
    gh_out "skipped=true"
    exit 0
  fi
  echo "🌐 Checking out '${PEERING_MANAGER_BRANCH}' of Peering Manager from the URL '${URL}' into '${PEERING_MANAGER_PATH}'"
  if [ ! -d "${PEERING_MANAGER_PATH}" ]; then
    $DRY git clone -q --depth 10 -b "${PEERING_MANAGER_BRANCH}" "${URL}" "${PEERING_MANAGER_PATH}"
  fi

  (
    $DRY cd "${PEERING_MANAGER_PATH}"

    if [ -n "${HTTP_PROXY}" ]; then
      git config http.proxy "${HTTP_PROXY}"
    fi

    $DRY git remote set-url origin "${URL}"
    $DRY git fetch -qp --depth 10 origin "${PEERING_MANAGER_BRANCH}"
    $DRY git checkout -qf FETCH_HEAD
    $DRY git prune
  )
  echo "✅ Checked out Peering Manager"
fi

gh_echo "::endgroup::"
gh_echo "::group::🧮 Calculating Values"

###
# Determining the value for DOCKERFILE
# and checking whether it exists
###
DOCKERFILE="${DOCKERFILE-Dockerfile}"
if [ ! -f "${DOCKERFILE}" ]; then
  echo "🚨 The Dockerfile ${DOCKERFILE} doesn't exist."

  if [ -z "${DEBUG}" ]; then
    exit 1
  else
    echo "⚠️  Would exit here with code '1', but DEBUG is enabled."
  fi
fi

###
# Determining the value for DOCKER_FROM
###
if [ -z "${DOCKER_FROM}" ]; then
  DOCKER_FROM="docker.io/alpine:3.20"
fi

###
# Variables for labelling the docker image
###
BUILD_DATE="$(date -u '+%Y-%m-%dT%H:%M+00:00')"

if [ -d ".git" ] && [ -z "${SKIP_GIT}" ]; then
  GIT_REF="$(git rev-parse HEAD)"
fi

# Read the project version from the `VERSION` file and trim it, see https://stackoverflow.com/a/3232433/172132
PROJECT_VERSION="${PROJECT_VERSION-$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' VERSION)}"

# Get the Git information from the peering-manager directory
if [ -d "${PEERING_MANAGER_PATH}/.git" ] && [ -z "${SKIP_GIT}" ]; then
  PEERING_MANAGER_GIT_REF=$(
    cd "${PEERING_MANAGER_PATH}"
    git rev-parse HEAD
  )
  PEERING_MANAGER_GIT_BRANCH=$(
    cd "${PEERING_MANAGER_PATH}"
    git rev-parse --abbrev-ref HEAD
  )
  PEERING_MANAGER_GIT_URL=$(
    cd "${PEERING_MANAGER_PATH}"
    git remote get-url origin
  )
fi

###
# Variables for tagging the docker image
###
DOCKER_REGISTRY="${DOCKER_REGISTRY-docker.io}"
DOCKER_ORG="${DOCKER_ORG-peeringmanager}"
DOCKER_REPO="${DOCKER_REPO-peering-manager}"
case "${PEERING_MANAGER_BRANCH}" in
  main)
    TAG="${TAG-snapshot}";;
  *)
    TAG="${TAG-$PEERING_MANAGER_BRANCH}";;
esac

###
# Composing the final TARGET_DOCKER_TAG
###
TARGET_DOCKER_TAG="${DOCKER_TAG-${TAG}}"
TARGET_DOCKER_TAG_PROJECT="${TARGET_DOCKER_TAG}-${PROJECT_VERSION}"

###
# Composing the additional DOCKER_SHORT_TAG,
# i.e. "v1.9.0" becomes "v1.9",
# which is only relevant for version tags
# Also let "latest" follow the highest version
###
if [[ "${TAG}" =~ ^v([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
  MAJOR=${BASH_REMATCH[1]}
  MINOR=${BASH_REMATCH[2]}

  TARGET_DOCKER_SHORT_TAG="${DOCKER_SHORT_TAG-v${MAJOR}.${MINOR}}"
  TARGET_DOCKER_LATEST_TAG="latest"
  TARGET_DOCKER_SHORT_TAG_PROJECT="${TARGET_DOCKER_SHORT_TAG}-${PROJECT_VERSION}"
  TARGET_DOCKER_LATEST_TAG_PROJECT="${TARGET_DOCKER_LATEST_TAG}-${PROJECT_VERSION}"
fi

IMAGE_NAME_TAGS=()
for IMAGE_NAME in "${IMAGE_NAMES[@]}"; do
  IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_TAG}")
  IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_TAG_PROJECT}")
done
if [ -n "${TARGET_DOCKER_SHORT_TAG}" ]; then
  for IMAGE_NAME in "${IMAGE_NAMES[@]}"; do
    IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_SHORT_TAG}")
    IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_SHORT_TAG_PROJECT}")
    IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_LATEST_TAG}")
    IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_LATEST_TAG_PROJECT}")
  done
fi

FINAL_DOCKER_TAG="${IMAGE_NAME_TAGS[0]}"
gh_env "FINAL_DOCKER_TAG=${IMAGE_NAME_TAGS[0]}"

###
# Checking if the build is necessary,
# meaning build only if one of those values changed:
# - a new tag is beeing created
# - base image digest
# - peering-manager git ref (Label: peering-manager.git-ref)
# - docker git ref (Label: org.opencontainers.image.revision)
###
# Load information from registry (only for first registry in "IMAGE_NAMES")
SHOULD_BUILD="false"
BUILD_REASON=""
if [ -z "${GH_ACTION}" ]; then
  # Asuming non Github builds should always proceed
  SHOULD_BUILD="true"
  BUILD_REASON="${BUILD_REASON} interactive"
elif [ "false" == "$(check_if_tags_exists "${IMAGE_NAMES[0]}" "$TARGET_DOCKER_TAG")" ]; then
  SHOULD_BUILD="true"
  BUILD_REASON="${BUILD_REASON} newtag"
else
  echo "Checking labels for '${FINAL_DOCKER_TAG}'"
  BASE_LAST_LAYER=$(get_image_last_layer "${DOCKER_FROM}")
  OLD_BASE_LAST_LAYER=$(get_image_label peering-manager.last-base-image-layer "${FINAL_DOCKER_TAG}")
  PEERING_MANAGER_GIT_REF_OLD=$(get_image_label peering-manager.git-ref "${FINAL_DOCKER_TAG}")
  GIT_REF_OLD=$(get_image_label org.opencontainers.image.revision "${FINAL_DOCKER_TAG}")

  if [ "${BASE_LAST_LAYER}" != "${OLD_BASE_LAST_LAYER}" ]; then
    SHOULD_BUILD="true"
    BUILD_REASON="${BUILD_REASON} alpine"
  fi
  if [ "${PEERING_MANAGER_GIT_REF}" != "${PEERING_MANAGER_GIT_REF_OLD}" ]; then
    SHOULD_BUILD="true"
    BUILD_REASON="${BUILD_REASON} peering-manager"
  fi
  if [ "${GIT_REF}" != "${GIT_REF_OLD}" ]; then
    SHOULD_BUILD="true"
    BUILD_REASON="${BUILD_REASON} peering-manager-docker"
  fi
fi

if [ "${SHOULD_BUILD}" != "true" ]; then
  echo "Build skipped because sources didn't change"
  gh_out "skipped=true"
  exit 0
else
  gh_out "skipped=false"
fi
gh_echo "::endgroup::"

if [ "${CHECK_ONLY}" = "true" ]; then
  echo "Only check if build needed was requested. Exiting"
  exit 0
fi

###
# Build the image
###
gh_echo "::group::🏗 Building the image"
###
# Composing all arguments for `docker build`
###
DOCKER_BUILD_ARGS=(
  --pull
  --target main
  -f "${DOCKERFILE}"
)
for IMAGE_NAME in "${IMAGE_NAME_TAGS[@]}"; do
  DOCKER_BUILD_ARGS+=(-t "${IMAGE_NAME}")
done

# --label
DOCKER_BUILD_ARGS+=(
  --label "peering-manager.original-tag=${TARGET_DOCKER_TAG_PROJECT}"
  --label "org.opencontainers.image.created=${BUILD_DATE}"
  --label "org.opencontainers.image.version=${PROJECT_VERSION}"
)
if [ -d ".git" ] && [ -z "${SKIP_GIT}" ]; then
  DOCKER_BUILD_ARGS+=(
    --label "org.opencontainers.image.revision=${GIT_REF}"
  )
fi
if [ -d "${PEERING_MANAGER_PATH}/.git" ] && [ -z "${SKIP_GIT}" ]; then
  DOCKER_BUILD_ARGS+=(
    --label "peering-manager.git-branch=${PEERING_MANAGER_GIT_BRANCH}"
    --label "peering-manager.git-ref=${PEERING_MANAGER_GIT_REF}"
    --label "peering-manager.git-url=${PEERING_MANAGER_GIT_URL}"
  )
fi
if [ -n "${BUILD_REASON}" ]; then
  BUILD_REASON=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$BUILD_REASON")
  DOCKER_BUILD_ARGS+=(--label "peering-manager.build-reason=${BUILD_REASON}")
  DOCKER_BUILD_ARGS+=(--label "peering-manager.last-base-image-layer=${BASE_LAST_LAYER}")
fi

# --build-arg
DOCKER_BUILD_ARGS+=(--build-arg "PEERING_MANAGER_PATH=${PEERING_MANAGER_PATH}")

if [ -n "${DOCKER_FROM}" ]; then
  DOCKER_BUILD_ARGS+=(--build-arg "FROM=${DOCKER_FROM}")
fi
if [ -n "${HTTP_PROXY}" ]; then
  DOCKER_BUILD_ARGS+=(--build-arg "http_proxy=${HTTP_PROXY}")
  DOCKER_BUILD_ARGS+=(--build-arg "https_proxy=${HTTPS_PROXY}")
fi
if [ -n "${NO_PROXY}" ]; then
  DOCKER_BUILD_ARGS+=(--build-arg "no_proxy=${NO_PROXY}")
fi

DOCKER_BUILD_ARGS+=(--platform "${BUILDX_PLATFORM-linux/amd64}")
if [ "${2}" == "--push" ]; then
  # output type=docker does not work with pushing
  DOCKER_BUILD_ARGS+=(
    --output=type=image
    --push
  )
else
  DOCKER_BUILD_ARGS+=(
    --output=type=docker
  )
fi

###
# Building the docker image
###
if [ -z "${BUILDX_BUILDER_NAME}" ]; then
  BUILDX_BUILDER_NAME="peeringmanager-docker"
fi
if ! docker buildx ls | grep --quiet --word-regexp "${BUILDX_BUILDER_NAME}"; then
  echo "👷  Creating new Buildx Builder '${BUILDX_BUILDER_NAME}'"
  $DRY docker buildx create --name "${BUILDX_BUILDER_NAME}"
  BUILDX_BUILDER_CREATED="yes"
fi

echo "🐳 Building the Docker image '${TARGET_DOCKER_TAG_PROJECT}'."
echo "    Build reason set to: ${BUILD_REASON}"
$DRY docker buildx \
  --builder "${BUILDX_BUILDER_NAME}" \
  build \
  "${DOCKER_BUILD_ARGS[@]}" \
  .
echo "✅ Finished building the Docker images"
gh_echo "::endgroup::"

gh_echo "::group::🏗 Image Labels"
echo "🔎 Inspecting labels on '${IMAGE_NAME_TAGS[0]}'"
$DRY docker inspect "${IMAGE_NAME_TAGS[0]}" --format "{{json .Config.Labels}}" | jq
gh_echo "::endgroup::"

gh_echo "::group::🏗 Clean up"
if [ -n "${BUILDX_REMOVE_BUILDER}" ] && [ "${BUILDX_BUILDER_CREATED}" == "yes" ]; then
  echo "👷  Removing Buildx Builder '${BUILDX_BUILDER_NAME}'"
  $DRY docker buildx rm "${BUILDX_BUILDER_NAME}"
fi
gh_echo "::endgroup::"
