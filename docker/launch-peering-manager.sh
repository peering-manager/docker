#!/bin/bash

UNIT_CONFIG="${UNIT_CONFIG-/etc/unit/nginx-unit.json}"
UNIT_RENDERED_CONFIG="/opt/unit/nginx-unit.json"
UNIT_SOCKET="/opt/unit/unit.sock"
STATIC_ROOT="/opt/unit/static-root"
BASE_PATH_FILE="/opt/unit/base-path"

# A user can set the base path with BASE_PATH but also in any configuration file,
# so ask Django for the value that the application really uses.
resolve_base_path() {
  local answer

  answer="$(
    PYTHONPATH=/opt/peering-manager \
      DJANGO_SETTINGS_MODULE=peering_manager.settings \
      /opt/peering-manager/venv/bin/python -c \
      'from django.conf import settings; print(f"__PM_BASE_PATH__:{settings.BASE_PATH}:")' \
      2>/dev/null | grep '^__PM_BASE_PATH__:' | tail -1
  )"

  if [ -n "${answer}" ]; then
    answer="${answer#__PM_BASE_PATH__:}"
    BASE_PATH="${answer%:}"
    return 0
  fi

  echo "⚠️  Could not read the base path from the configuration; using BASE_PATH"

  # Normalise the variable the way Django normalises it
  BASE_PATH="$(echo "${BASE_PATH-}" | sed -e 's|^/*||' -e 's|/*$||')"
  if [ -n "${BASE_PATH}" ]; then
    BASE_PATH="${BASE_PATH}/"
  fi
}

publish_base_path() {
  # The health check reads it to build the URL it asks for
  if ! echo "${BASE_PATH}" >"${BASE_PATH_FILE}"; then
    echo "⚠️  Could not write the base path to ${BASE_PATH_FILE}"
    return 1
  fi
}

prepare_static_files() {
  # Unit cannot strip the base path from a URI, so publish the static directory
  # under the base path with a symbolic link
  if ! (rm -rf "${STATIC_ROOT}" &&
    mkdir -p "${STATIC_ROOT}/${BASE_PATH}" &&
    ln -sfn /opt/peering-manager/static "${STATIC_ROOT}/${BASE_PATH}static"); then
    echo "⚠️  Could not publish the static files in ${STATIC_ROOT}"
    return 1
  fi
}

render_configuration() {
  if ! sed -e "s|__BASE_PATH__|${BASE_PATH}|g" "${UNIT_CONFIG}" >"${UNIT_RENDERED_CONFIG}"; then
    echo "⚠️  Could not write the Unit configuration to ${UNIT_RENDERED_CONFIG}"
    return 1
  fi
}

load_configuration() {
  MAX_WAIT=10
  WAIT_COUNT=0
  while [ ! -S ${UNIT_SOCKET} ]; do
    if [ ${WAIT_COUNT} -ge ${MAX_WAIT} ]; then
      echo "⚠️  No control socket found; configuration will not be loaded."
      return 1
    fi

    WAIT_COUNT=$((WAIT_COUNT + 1))
    echo "⏳ Waiting for control socket to be created... (${WAIT_COUNT}/${MAX_WAIT})"

    sleep 1
  done

  # even when the control socket exists, it does not mean unit has finished initialisation
  # this curl call will get a reply once unit is fully launched
  curl --silent --output /dev/null --request GET --unix-socket ${UNIT_SOCKET} http://localhost/

  echo "⚠️  Applying configuration from ${UNIT_CONFIG}"

  RESP_CODE=$(
    curl \
      --silent \
      --output /dev/null \
      --write-out '%{http_code}' \
      --request PUT \
      --data-binary "@${UNIT_RENDERED_CONFIG}" \
      --unix-socket $UNIT_SOCKET \
      http://localhost/config
  )
  if [ "${RESP_CODE}" != "200" ]; then
    echo "⚠ Could no load Unit configuration"
    kill "$(cat /opt/unit/unit.pid)"
    return 1
  fi

  echo "✅ Unit configuration loaded successfully"
}

resolve_base_path
publish_base_path
prepare_static_files
render_configuration

load_configuration &

exec unitd \
  --no-daemon \
  --control unix:${UNIT_SOCKET} \
  --pid /opt/unit/unit.pid \
  --log /dev/stdout \
  --statedir /opt/unit/state/ \
  --tmpdir /opt/unit/tmp/ \
  --user unit \
  --group root
