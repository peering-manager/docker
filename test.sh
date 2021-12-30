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

test_peeringmanager_unit_tests() {
  echo "⏱ Running NetBox Unit Tests"
  $doco run --rm peering-manager /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py test
}

echo "🐳 Start testing '${IMAGE}'"
test_peeringmanager_unit_tests
echo "🐳 Done testing '${IMAGE}'"
