#!/bin/bash
SECONDS=${COMMAND_INTERVAL:=86400}

echo "Interval set to ${SECONDS} seconds"
while true; do
  date
  /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py ${@}
  sleep "${SECONDS}s"
done
