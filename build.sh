#!/bin/bash
# Clones the Peering Manager repository from Github and builds the Dockerfile

echo "▶️ $0 $*"

set -e

if [ "${1}x" == "x" ] || [ "${1}" == "--help" ] || [ "${1}" == "-h" ]; then
  echo "Usage: ${0} <branch> [--push|--push-only]"
  echo "  branch       The branch or tag to build. Required."
  echo "  --push       Pushes the built Docker image to the registry."
  echo "  --push-only  Only pushes the Docker image to the registry, but does not build it."
  echo ""
  echo "You can use the following ENV variables to customize the build:"
  echo "  SRC_ORG     Which fork of peering-manager to use (i.e. github.com/\${SRC_ORG}/\${SRC_REPO})."
  echo "              Default: peering-manager"
  echo "  SRC_REPO    The name of the repository to use (i.e. github.com/\${SRC_ORG}/\${SRC_REPO})."
  echo "              Default: peering-manager"
  echo "  URL         Where to fetch the code from."
  echo "              Must be a git repository. Can be private."
  echo "              Default: https://github.com/\${SRC_ORG}/\${SRC_REPO}.git"
  echo "  PEERING_MANAGER_PATH The path where peering-manager will be checkout out."
  echo "              Must not be outside of the peering-manager docker repository (because of Docker)!"
  echo "              Default: .peering-manager"
  echo "  SKIP_GIT    If defined, git is not invoked and \${PEERING_MANAGER_PATH} will not be altered."
  echo "              This may be useful, if you are manually managing the PEERING_MANAGER_PATH."
  echo "              Default: undefined"
  echo "  TAG         The version part of the docker tag."
  echo "              Default:"
  echo "                When <branch>=main: snapshot"
  echo "                Else:               same as <branch>"
  echo "  DOCKER_REGISTRY The Docker repository's registry (i.e. '\${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}'')"
  echo "              Used for tagging the image."
  echo "              Default: docker.io"
  echo "  DOCKER_ORG  The Docker repository's organisation (i.e. '\${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}'')"
  echo "              Used for tagging the image."
  echo "              Default: peering-manager"
  echo "  DOCKER_REPO The Docker repository's name (i.e. '\${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}'')"
  echo "              Used for tagging the image."
  echo "              Default: peering-manager"
  echo "  DOCKER_TAG  The name of the tag which is applied to the image."
  echo "              Useful for pushing into another registry than hub.docker.com."
  echo "              Default: \${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}:\${TAG}"
  echo "  DOCKER_SHORT_TAG The name of the short tag which is applied to the"
  echo "              image. This is used to tag all patch releases to their"
  echo "              containing version e.g. v1.5.2 -> v1.5"
  echo "              Default: \${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}:<MAJOR>.<MINOR>"
  echo "  DOCKERFILE  The name of Dockerfile to use."
  echo "              Default: Dockerfile"
  echo "  DOCKER_TARGET A specific target to build."
  echo "              It's currently not possible to pass multiple targets."
  echo "              Default: main ldap"
  echo "  HTTP_PROXY  The proxy to use for http requests."
  echo "              Example: http://proxy.domain.tld:3128"
  echo "              Default: undefined"
  echo "  NO_PROXY    Comma-separated list of domain extensions proxy should not be used for."
  echo "              Example: .domain1.tld,.domain2.tld"
  echo "              Default: undefined"
  echo "  DEBUG       If defined, the script does not stop when certain checks are unsatisfied."
  echo "              Default: undefined"
  echo "  DRY_RUN     Prints all build statements instead of running them."
  echo "              Default: undefined"
  echo "  GH_ACTION   If defined, special 'echo' statements are enabled that set the"
  echo "              following environment variables in Github Actions:"
  echo "              - FINAL_DOCKER_TAG: The final value of the DOCKER_TAG env variable"
  echo "              Default: undefined"
  echo ""
  echo "Examples:"
  echo "  ${0} main"
  echo "              This will fetch the latest 'main' branch, build a Docker Image and tag it"
  echo "              'peering-manager/peering-manager:latest'."
  echo "  ${0} v1.5.2"
  echo "              This will fetch the 'v1.5.2' tag, build a Docker Image and tag it"
  echo "              'peering-manager/peering-manager:v1.5.2' and 'peering-manager/peering-manager:v1.5'."
  echo "  SRC_ORG=peering-manager ${0} feature-x"
  echo "              This will fetch the 'feature-x' branch from https://github.com/peering-manager/peering-manager.git",
  echo "              build a Docker Image and tag it 'peering-manager/peering-manager:feature-x'."
  echo "  SRC_ORG=peering-manager DOCKER_ORG=peering-manager ${0} feature-x"
  echo "              This will fetch the 'feature-x' branch from https://github.com/peering-manager/peering-manager.git",
  echo "              build a Docker Image and tag it 'peering-manager/peering-manager:feature-x'."

  if [ "${1}x" == "x" ]; then
    exit 1
  else
    exit 0
  fi
fi

source ./build-functions/gh-functions.sh

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
    gh_echo "::set-output name=skipped::true"
    exit 0
  fi
  echo "🌐 Checking out '${PEERING_MANAGER_BRANCH}' of peering-manager from the url '${URL}' into '${PEERING_MANAGER_PATH}'"
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
  echo "✅ Checked out peering-manager"
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
# Variables for labelling the docker image
###
BUILD_DATE="$(date -u '+%Y-%m-%dT%H:%M+00:00')"

if [ -d ".git" ]; then
  GIT_REF="$(git rev-parse HEAD)"
fi

# Read the project version from the `VERSION` file and trim it, see https://stackoverflow.com/a/3232433/172132
PROJECT_VERSION="${PROJECT_VERSION-$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' VERSION)}"

# Get the Git information from the peering-manager directory
if [ -d "${PEERING_MANAGER_PATH}/.git" ]; then
  PEERING_MANAGER_GIT_REF=$(cd "${PEERING_MANAGER_PATH}"; git rev-parse HEAD)
  PEERING_MANAGER_GIT_BRANCH=$(cd "${PEERING_MANAGER_PATH}"; git rev-parse --abbrev-ref HEAD)
  PEERING_MANAGER_GIT_URL=$(cd "${PEERING_MANAGER_PATH}"; git remote get-url origin)
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
# Determine targets to build
###
DEFAULT_DOCKER_TARGETS=("main" "ldap")
DOCKER_TARGETS=( "${DOCKER_TARGET:-"${DEFAULT_DOCKER_TARGETS[@]}"}")
echo "🏭 Building the following targets:" "${DOCKER_TARGETS[@]}"

gh_echo "::endgroup::"

###
# Build each target
###
export DOCKER_BUILDKIT=${DOCKER_BUILDKIT-1}
for DOCKER_TARGET in "${DOCKER_TARGETS[@]}"; do
  gh_echo "::group::🏗 Building the target '${DOCKER_TARGET}'"
  echo "🏗 Building the target '${DOCKER_TARGET}'"

  ###
  # composing the final TARGET_DOCKER_TAG
  ###
  TARGET_DOCKER_TAG="${DOCKER_TAG-${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:${TAG}}"
  if [ "${DOCKER_TARGET}" != "main" ]; then
    TARGET_DOCKER_TAG="${TARGET_DOCKER_TAG}-${DOCKER_TARGET}"
  else
    gh_env "FINAL_DOCKER_TAG=${TARGET_DOCKER_TAG}"
  fi
  gh_echo "::set-output name=skipped::false"

  ###
  # composing the additional DOCKER_SHORT_TAG,
  # i.e. "v1.5.2" becomes "v1.5",
  # which is only relevant for version tags
  # Also let "latest" follow the highest version
  ###
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

  ###
  # Proceeding to buils stage, except if `--push-only` is passed
  ###
  if [ "${2}" != "--push-only" ] ; then
    ###
    # Checking if the build is necessary,
    # meaning build only if one of those values changed:
    # - Python base image digest (Label: PYTHON_BASE_DIGEST)
    # - peering-manager git ref (Label: PEERING_MANAGER_GIT_REF)
    # - peering-manager-docker git ref (Label: org.label-schema.vcs-ref)
    ###
    # Load information from registry (only for docker.io)
    SHOULD_BUILD="false"
    BUILD_REASON=""
    if [ -z "${GH_ACTION}" ]; then
      # Asuming non Github builds should always proceed
      SHOULD_BUILD="true"
      BUILD_REASON="${BUILD_REASON} interactive"
    elif [ "$DOCKER_REGISTRY" = "docker.io" ]; then
      source ./build-functions/get-public-image-config.sh
      IFS=':' read -ra DOCKER_FROM_SPLIT <<< "${DOCKER_FROM}"
      if ! [[ ${DOCKER_FROM_SPLIT[0]} =~ .*/.* ]]; then
        # Need to use "library/..." for images the have no two part name
        DOCKER_FROM_SPLIT[0]="library/${DOCKER_FROM_SPLIT[0]}"
      fi
      PYTHON_LAST_LAYER=$(get_image_last_layer "${DOCKER_FROM_SPLIT[0]}" "${DOCKER_FROM_SPLIT[1]}")
      mapfile -t IMAGES_LAYERS_OLD < <(get_image_layers "${DOCKER_ORG}"/"${DOCKER_REPO}" "${TAG}")
      PEERING_MANAGER_GIT_REF_OLD=$(get_image_label PEERING_MANAGER_GIT_REF "${DOCKER_ORG}"/"${DOCKER_REPO}" "${TAG}")
      GIT_REF_OLD=$(get_image_label org.label-schema.vcs-ref "${DOCKER_ORG}"/"${DOCKER_REPO}" "${TAG}")

      if ! printf '%s\n' "${IMAGES_LAYERS_OLD[@]}" | grep -q -P "^${PYTHON_LAST_LAYER}\$"; then
        SHOULD_BUILD="true"
        BUILD_REASON="${BUILD_REASON} python"
      fi
      if [ "${PEERING_MANAGER_GIT_REF}" != "${PEERING_MANAGER_GIT_REF_OLD}" ]; then
        SHOULD_BUILD="true"
        BUILD_REASON="${BUILD_REASON} peering-manager"
      fi
      if [ "${GIT_REF}" != "${GIT_REF_OLD}" ]; then
        SHOULD_BUILD="true"
        BUILD_REASON="${BUILD_REASON} peering-manager-docker"
      fi
    else
      SHOULD_BUILD="true"
      BUILD_REASON="${BUILD_REASON} no-check"
    fi
    ###
    # Composing all arguments for `docker build`
    ###
    DOCKER_BUILD_ARGS=(
      --pull
      --target "${DOCKER_TARGET}"
      -f "${DOCKERFILE}"
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
    if [ -n "${BUILD_REASON}" ]; then
      BUILD_REASON=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$BUILD_REASON")
      DOCKER_BUILD_ARGS+=( --label "BUILD_REASON=${BUILD_REASON}" )
    fi

    # --build-arg
    DOCKER_BUILD_ARGS+=(   --build-arg "PEERING_MANAGER_PATH=${PEERING_MANAGER_PATH}" )

    if [ -n "${HTTP_PROXY}" ]; then
      DOCKER_BUILD_ARGS+=( --build-arg "http_proxy=${HTTP_PROXY}" )
      DOCKER_BUILD_ARGS+=( --build-arg "https_proxy=${HTTPS_PROXY}" )
    fi
    if [ -n "${NO_PROXY}" ]; then
      DOCKER_BUILD_ARGS+=( --build-arg "no_proxy=${NO_PROXY}" )
    fi

    ###
    # Building the docker image
    ###
    if [ "${SHOULD_BUILD}" == "true" ]; then
      echo "🐳 Building the Docker image '${TARGET_DOCKER_TAG}'."
      echo "    Build reason set to: ${BUILD_REASON}"
      $DRY docker build "${DOCKER_BUILD_ARGS[@]}" .
      echo "✅ Finished building the Docker images '${TARGET_DOCKER_TAG}'"
      echo "🔎 Inspecting labels on '${TARGET_DOCKER_TAG}'"
      $DRY docker inspect "${TARGET_DOCKER_TAG}" --format "{{json .Config.Labels}}"
    else
      echo "Build skipped because sources didn't change"
      echo "::set-output name=skipped::true"
    fi
  fi

  ###
  # Pushing the docker images if either `--push` or `--push-only` are passed
  ###
  if [ "${2}" == "--push" ] || [ "${2}" == "--push-only" ] ; then
    source ./build-functions/docker-functions.sh
    push_image_to_registry "${TARGET_DOCKER_TAG}"

    if [ -n "${TARGET_DOCKER_SHORT_TAG}" ]; then
      push_image_to_registry "${TARGET_DOCKER_SHORT_TAG}"
      push_image_to_registry "${TARGET_DOCKER_LATEST_TAG}"
    fi
  fi

  gh_echo "::endgroup::"
done
