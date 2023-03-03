#!/bin/bash
SLEEP_SECONDS=${COMMAND_INTERVAL:=86400}

echo "Interval set to ${SLEEP_SECONDS} seconds"
while true; do
  date
  /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py ${@}
  sleep "${SLEEP_SECONDS}s"
done
