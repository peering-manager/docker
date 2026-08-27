#!/bin/bash
# Checks that Peering Manager answers, whatever base path it is served under

BASE_PATH_FILE="/opt/unit/base-path"

if [ -r "${BASE_PATH_FILE}" ]; then
  # Written by the launch script from the Django settings
  BASE_PATH="$(cat "${BASE_PATH_FILE}")"
else
  # Fall back to the variable, normalised the way Django normalises it
  BASE_PATH="$(echo "${BASE_PATH-}" | sed -e 's|^/*||' -e 's|/*$||')"
  if [ -n "${BASE_PATH}" ]; then
    BASE_PATH="${BASE_PATH}/"
  fi
fi

exec curl --fail --silent --output /dev/null "http://localhost:8080/${BASE_PATH}login/"
