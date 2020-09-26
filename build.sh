#!/bin/bash

echo "▶️  $0 $*"

set -e

if [ "${1}x" == "x" ] || [ "${1}" == "--help" ] || [ "${1}" == "-h" ]; then
  echo ""
  echo "Usage: ${0} <branch>"
  echo "  branch    The branch or tag to build. Required."
  echo ""
  echo "You can use the following ENV variables to customize the build:"
  echo "  SRC_ORG     Which fork of netbox to use (i.e. github.com/\${SRC_ORG}/\${SRC_REPO})."
  echo "              Default: peering-manager"
  echo "  SRC_REPO    The name of the repository to use (i.e. github.com/\${SRC_ORG}/\${SRC_REPO})."
  echo "              Default: peering-manager"
  echo "  URL         Where to fetch the code from."
  echo "              Must be a git repository. Can be private."
  echo "              Default: https://github.com/\${SRC_ORG}/\${SRC_REPO}.git"
  echo "  DEBUG       If defined, the script does not stop when certain checks are unsatisfied."
  echo "              Default: undefined"
  echo "  DRY_RUN     Prints all build statements instead of running them."
  echo "              Default: undefined"
  echo ""
  echo "Examples:"
  echo "  ${0} master"
  echo "              This will fetch the latest 'master' branch, build a Docker Image and tag it"
  echo "              'peering-manager/peering-manager:latest'."
  echo "  ${0} v1.2.0"
  echo "              This will fetch the 'v1.2.0' tag, build a Docker Image and tag it"
  echo "              'peeringmanager/peering-manager:v1.2.0' and 'peeringmanager/peering-manager:v1.2'."
  echo ""

  if [ "${1}x" == "x" ]; then
    exit 1
  else
    exit 0
  fi
fi

# Enabling dry-run mode
if [ -z "${DRY_RUN}" ]; then
  DRY=""
else
  echo "⚠️  DRY_RUN MODE ON ⚠️"
  DRY="echo"
fi

echo "👓 Going in the right location"
cd $(dirname $(realpath $0))
echo "✅ We are there"

# Variables for fetching the source
SRC_ORG="${SRC_ORG-peering-manager}"
SRC_REPO="${SRC_REPO-peering-manager}"
PEERING_MANAGER_BRANCH="${1}"
URL="${URL-https://github.com/${SRC_ORG}/${SRC_REPO}.git}"
PEERING_MANAGER_PATH="${PEERING_MANAGER_PATH-.peering-manager}"

echo "🌀 Cleaning up remains of last build"
$DRY rm -rf ${PEERING_MANAGER_PATH}
echo "✅ All cleaned"

echo "🌐 Checking out 'master' of Peering Manager from '${URL}' into '${PEERING_MANAGER_PATH}'"
$DRY git clone -q --depth 10 -b ${PEERING_MANAGER_BRANCH} ${URL} ${PEERING_MANAGER_PATH}
echo "✅ Checked out Peering Manager"

# Variables for tagging the Docker image
DOCKER_REGISTRY="${DOCKER_REGISTRY-docker.io}"
DOCKER_ORG="${DOCKER_ORG-peeringmanager}"
DOCKER_REPO="${DOCKER_REPO-peering-manager}"
case "${PEERING_MANAGER_BRANCH}" in
  master)
    TAG="${TAG-master}";;
  *)
    TAG="${TAG-$PEERING_MANAGER_BRANCH}";;
esac

BUILD_DATE="$(date -u '+%Y-%m-%dT%H:%M+00:00')"

if [ -d ".git" ]; then
  GIT_REF="$(git rev-parse HEAD)"
fi

# Read the project version from the `VERSION` file and trim it
# See https://stackoverflow.com/a/3232433/172132
PROJECT_VERSION="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' VERSION)"

# Get the Git information from the netbox directory
if [ -d "${PEERING_MANAGER_PATH}/.git" ]; then
  PEERING_MANAGER_GIT_REF=$(cd "${PEERING_MANAGER_PATH}"; git rev-parse HEAD)
  PEERING_MANAGER_GIT_BRANCH=$(cd "${PEERING_MANAGER_PATH}"; git rev-parse --abbrev-ref HEAD)
  PEERING_MANAGER_GIT_URL=$(cd "${PEERING_MANAGER_PATH}"; git remote get-url origin)
fi

# Determine targets to build
DEFAULT_DOCKER_TARGETS=("main")
DOCKER_TARGETS=("${DOCKER_TARGET:-"${DEFAULT_DOCKER_TARGETS[@]}"}")
echo "🏭 Building the following targets:" "${DOCKER_TARGETS[@]}"

for DOCKER_TARGET in "${DOCKER_TARGETS[@]}"; do
  echo "🏗  Building the target '${DOCKER_TARGET}'"

  # composing the final TARGET_DOCKER_TAG
  TARGET_DOCKER_TAG="${DOCKER_TAG-${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:${TAG}}"
  if [ "${DOCKER_TARGET}" != "main" ]; then
    TARGET_DOCKER_TAG="${TARGET_DOCKER_TAG}-${DOCKER_TARGET}"
  fi

  # composing the additional DOCKER_SHORT_TAG,
  # i.e. "v1.2.0" becomes "v1.2",
  # which is only relevant for version tags
  # Also let "latest" follow the highest version
  if [[ "${TAG}" =~ ^v([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
    MAJOR=${BASH_REMATCH[1]}
    MINOR=${BASH_REMATCH[2]}

    TARGET_DOCKER_SHORT_TAG="${DOCKER_SHORT_TAG-${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:v${MAJOR}.${MINOR}}"
    TARGET_DOCKER_LATEST_TAG="${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:latest"

    if [ "${DOCKER_TARGET}" != "main" ]; then
      TARGET_DOCKER_SHORT_TAG="${TARGET_DOCKER_SHORT_TAG}-${DOCKER_TARGET}"
      TARGET_DOCKER_LATEST_TAG="${TARGET_DOCKER_LATEST_TAG}-${DOCKER_TARGET}"
    fi
  fi

  # Composing all arguments for `docker build`
  DOCKER_BUILD_ARGS=(
    --pull
    --target "${DOCKER_TARGET}"
    -t "${TARGET_DOCKER_TAG}"
  )
  if [ -n "${TARGET_DOCKER_SHORT_TAG}" ]; then
    DOCKER_BUILD_ARGS+=( -t "${TARGET_DOCKER_SHORT_TAG}" )
    DOCKER_BUILD_ARGS+=( -t "${TARGET_DOCKER_LATEST_TAG}" )
  fi

  # --label
  DOCKER_BUILD_ARGS+=(
    --label "ORIGINAL_TAG=${TARGET_DOCKER_TAG}"

    --label "org.label-schema.build-date=${BUILD_DATE}"
    --label "org.opencontainers.image.created=${BUILD_DATE}"

    --label "org.label-schema.version=${PROJECT_VERSION}"
    --label "org.opencontainers.image.version=${PROJECT_VERSION}"
  )
  if [ -d ".git" ]; then
    DOCKER_BUILD_ARGS+=(
      --label "org.label-schema.vcs-ref=${GIT_REF}"
      --label "org.opencontainers.image.revision=${GIT_REF}"
    )
  fi
  if [ -d "${PEERING_MANAGER_PATH}/.git" ]; then
    DOCKER_BUILD_ARGS+=(
      --label "PEERING_MANAGER_GIT_BRANCH=${PEERING_MANAGER_GIT_BRANCH}"
      --label "PEERING_MANAGER_GIT_REF=${PEERING_MANAGER_GIT_REF}"
      --label "PEERING_MANAGER_GIT_URL=${PEERING_MANAGER_GIT_URL}"
    )
  fi

  # --build-arg
  DOCKER_BUILD_ARGS+=( --build-arg "PEERING_MANAGER_PATH=${PEERING_MANAGER_PATH}" )

  # Building the Docker image
  echo "🐳 Building the Docker image '${TARGET_DOCKER_TAG}'."
  $DRY docker build "${DOCKER_BUILD_ARGS[@]}" .
  echo "✅ Finished building the Docker images '${TARGET_DOCKER_TAG}'"
  echo "🔎 Inspecting labels on '${TARGET_DOCKER_TAG}'"
  $DRY docker inspect "${TARGET_DOCKER_TAG}" --format "{{json .Config.Labels}}"
done
