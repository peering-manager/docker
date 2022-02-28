#!/bin/bash
# Runs on every start of the Peering Manager Docker container

# Stop when an error occures
set -e

# Allows Peering Manager to be run as non-root users
umask 002

# Load correct Python3 env
# shellcheck disable=SC1091
source /opt/peering-manager/venv/bin/activate

# Try to connect to the DB
DB_WAIT_TIMEOUT=${DB_WAIT_TIMEOUT-3}
MAX_DB_WAIT_TIME=${MAX_DB_WAIT_TIME-30}
CUR_DB_WAIT_TIME=0

while [ "${CUR_DB_WAIT_TIME}" -lt "${MAX_DB_WAIT_TIME}" ]; do
  # Read and truncate connection error tracebacks to last line by default
  exec {psfd}< <(./manage.py showmigrations 2>&1)
  read -rd '' DB_ERR <&$psfd || :
  exec {psfd}<&-
  wait $! && break
  if [ -n "$DB_WAIT_DEBUG" ]; then
    echo "$DB_ERR"
  else
    readarray -tn 0 DB_ERR_LINES <<<"$DB_ERR"
    echo "${DB_ERR_LINES[@]: -1}"
    echo "[ Use DB_WAIT_DEBUG=1 in peering-manager.env to print full traceback for errors here ]"
  fi
  echo "⏳ Waiting on database... (${CUR_DB_WAIT_TIME}s / ${MAX_DB_WAIT_TIME}s)"
  sleep "${DB_WAIT_TIMEOUT}"
  CUR_DB_WAIT_TIME=$((CUR_DB_WAIT_TIME + DB_WAIT_TIMEOUT))
done
if [ "${CUR_DB_WAIT_TIME}" -ge "${MAX_DB_WAIT_TIME}" ]; then
  echo "❌ Waited ${MAX_DB_WAIT_TIME}s or more for the database to become ready."
  exit 1
fi

# Check if update is needed
if ! ./manage.py migrate --check >/dev/null 2>&1; then
  echo "🗜  Applying database migrations"
  ./manage.py migrate --no-input
  echo "🗜  Removing stale content types"
  ./manage.py remove_stale_contenttypes --no-input
  echo "🗜  Removing expired user sessions"
  ./manage.py clearsessions
fi

# Create Superuser if required
if [ "$SKIP_SUPERUSER" == "true" ]; then
  echo "↩ Skip creating the superuser"
else
  if [ -z ${SUPERUSER_NAME+x} ]; then
    SUPERUSER_NAME='admin'
  fi
  if [ -z ${SUPERUSER_EMAIL+x} ]; then
    SUPERUSER_EMAIL='admin@example.com'
  fi
  if [ -z ${SUPERUSER_PASSWORD+x} ]; then
    if [ -f "/run/secrets/superuser_password" ]; then
      SUPERUSER_PASSWORD="$(< /run/secrets/superuser_password)"
    else
      SUPERUSER_PASSWORD='admin'
    fi
  fi
  if [ -z ${SUPERUSER_API_TOKEN+x} ]; then
    if [ -f "/run/secrets/superuser_api_token" ]; then
      SUPERUSER_API_TOKEN="$(< /run/secrets/superuser_api_token)"
    else
      SUPERUSER_API_TOKEN='0123456789abcdef0123456789abcdef01234567'
    fi
  fi

  ./manage.py shell --interface python << END
from django.contrib.auth.models import User
from users.models import Token
if not User.objects.filter(username='${SUPERUSER_NAME}'):
    u = User.objects.create_superuser('${SUPERUSER_NAME}', '${SUPERUSER_EMAIL}', '${SUPERUSER_PASSWORD}')
    Token.objects.create(user=u, key='${SUPERUSER_API_TOKEN}')
END

  echo "💡 Superuser Username: ${SUPERUSER_NAME}, E-Mail: ${SUPERUSER_EMAIL}"
fi

# Run the startup scripts (and initializers)
if [ "$SKIP_STARTUP_SCRIPTS" == "true" ]; then
  echo "↩ Skipping startup scripts"
else
  echo "import runpy; runpy.run_path('startup_scripts')" | ./manage.py shell --interface python
fi

# Copy static files
./manage.py collectstatic --no-input

echo "✅ Initialisation is done."

# Launch whatever is passed by docker
# (i.e. the RUN instruction in the Dockerfile)
exec "$@"
