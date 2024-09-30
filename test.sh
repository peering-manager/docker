#!/bin/bash
# Runs the Peering Manager unit tests.
# Usage:
#   ./test.sh latest
#   ./test.sh v1.8.3
#   IMAGE='peeringmanager/peering-manager:latest' ./test.sh
#   IMAGE='peeringmanager/peering-manager:v1.8.3' ./test.sh

# exit when a command exits with an exit code != 0
set -e

source ./build-functions/gh-functions.sh

# IMAGE is used by `docker-compose.yml` do determine the tag
# of the Docker Image that is to be used
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
doco="docker compose --file docker-compose.test.yml --file docker-compose.test.override.yml --project-name peeringmanager_docker_test"

test_setup() {
  gh_echo "::group:: Test setup"
  echo "🏗  Setup up test environment"

  $doco up --detach --quiet-pull --wait --force-recreate --renew-anon-volumes --no-start
  $doco start postgres
  $doco start redis
  $doco start redis-cache
  gh_echo "::endgroup::"
}

test_peeringmanager_unit_tests() {
  gh_echo "::group:: Peering Manager unit tests"
  echo "⏱  Running Peering Manager Unit Tests"
  $doco run --rm peering-manager /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py test
  gh_echo "::endgroup::"
}

test_compose_db_setup() {
  gh_echo "::group:: Peering Manager database migrations"
  echo "⏱ Running Peering Manager database migrations"
  $doco run --rm peering-manager /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py migrate
  gh_echo "::endgroup::"
}

test_peeringmanager_start() {
  gh_echo "::group:: Start Peering Manager service"
  echo "⏱ Starting Peering Manager services"
  $doco up --detach --wait
  gh_echo "::endgroup::"
}

test_peeringmanager_web() {
  gh_echo "::group:: Web service test"
  echo "⏱ Starting web service test"
  RESP_CODE=$(
    curl \
      --silent \
      --output /dev/null \
      --write-out '%{http_code}' \
      --request GET \
      --connect-timeout 5 \
      --max-time 10 \
      --retry 5 \
      --retry-delay 0 \
      --retry-max-time 40 \
      http://localhost:8000/login/
  )
  if [ "${RESP_CODE}" == "200" ]; then
    echo "✅ Web service running"
  else
    echo "⚠️ Got response code '${RESP_CODE}' but expected '200'"
    exit 1
  fi
  gh_echo "::endgroup::"
}

test_cleanup() {
  echo "💣 Cleaning Up"
  gh_echo "::group:: Docker compose logs"
  $doco logs --no-color
  gh_echo "::endgroup::"
  gh_echo "::group:: Docker compose down"
  $doco down --volumes
  gh_echo "::endgroup::"
}

echo "🐳 Start testing '${IMAGE}'"

# Make sure the cleanup script is executed
trap test_cleanup EXIT ERR
test_setup

test_peeringmanager_unit_tests
test_compose_db_setup
test_peeringmanager_start
test_peeringmanager_web

echo "🐳 Done testing '${IMAGE}'"
