#!/bin/bash
SECONDS=${HOUSEKEEPING_INTERVAL:=86400}

echo "Interval set to ${SECONDS} seconds"
while true; do
  date
  /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py housekeeping
  sleep "${SECONDS}s"
done
