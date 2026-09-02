#!/bin/bash
DELAY_SECONDS=${COMMAND_DELAY:=0}
SLEEP_SECONDS=${COMMAND_INTERVAL:=86400}

echo "Initial delay set to ${DELAY_SECONDS} seconds"
echo "Interval set to ${SLEEP_SECONDS} seconds"
sleep "${DELAY_SECONDS}s"
while true; do
  date
  /opt/peering-manager/venv/bin/python /opt/peering-manager/manage.py ${@}
  sleep "${SLEEP_SECONDS}s"
done
