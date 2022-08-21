#!/bin/bash
SECONDS=${PEERINGDB_SYNC_INTERVAL:=86400}

echo "Interval set to ${SECONDS} seconds"
while true; do
  date
  /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py peeringdb_sync
  sleep "${SECONDS}s"
done
