#!/bin/bash
# Runs the Peering Manager unit tests.
# Usage:
#   ./test.sh latest
#   ./test.sh v1.5.2
#   IMAGE='peeringmanager/peering-manager:latest' ./test.sh
#   IMAGE='peeringmanager/peering-manager:v1.5.2' ./test.sh

# exit when a command exits with an exit code != 0
set -e

if [ "${1}x" != "x" ]; then
  # Use the command line argument
  export IMAGE="peeringmanager/peering-manager:${1}"
else
  export IMAGE="${IMAGE-peeringmanager/peering-manager:latest}"
fi

# Ensure that an IMAGE is defined
if [ -z "${IMAGE}" ]; then
  echo "⚠️ No image defined"

  if [ -z "${DEBUG}" ]; then
    exit 1
  else
    echo "⚠️  Would 'exit 1' here, but DEBUG is '${DEBUG}'."
  fi
fi

# The docker compose command to use
doco="docker-compose --file docker-compose.test.yml --project-name peeringmanager_docker_test_${1}"
INITIALIZERS_DIR=".initializers"

test_setup() {
  echo "🏗  Setup up test environment"
  if [ -d "${INITIALIZERS_DIR}" ]; then
    rm -rf "${INITIALIZERS_DIR}"
  fi

  mkdir "${INITIALIZERS_DIR}"
  (
    cd initializers
    for script in *.yml; do
      sed -E 's/^# //' "${script}" > "../${INITIALIZERS_DIR}/${script}"
    done
  )
}

test_peeringmanager_unit_tests() {
  echo "⏱  Running Peering Manager Unit Tests"
  $doco run --rm peering-manager /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py test
}

test_initializers() {
  echo "🏭 Testing Initializers"
  export INITIALIZERS_DIR
  $doco run --rm peering-manager /opt/peering-manager/docker-entrypoint.sh ./manage.py check
}

test_cleanup() {
  echo "💣 Cleaning Up"
  $doco down -v

  if [ -d "${INITIALIZERS_DIR}" ]; then
    rm -rf "${INITIALIZERS_DIR}"
  fi
}

echo "🐳 Start testing '${IMAGE}'"

# Make sure the cleanup script is executed
trap test_cleanup EXIT ERR
test_setup

test_peeringmanager_unit_tests
test_initializers

echo "🐳 Done testing '${IMAGE}'"
